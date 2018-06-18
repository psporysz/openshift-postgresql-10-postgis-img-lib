# 
# File:
#   Dockerfile
# 
# Description:
#   The Dockerfile for image adrianbartyczak/openshift-postgresql-10-postgis
# 

FROM openshift/base-centos7

# ============================================
#   Set up the system
# ============================================

# Enable the EPEL repository as it is needed by the dependecies of PostGIS.
RUN yum -y install epel-release
# Import the EPEL GPG-key to ensure that package integrity has not been
# compromised.
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

# ============================================
#   Install PostgreSQL and PostGIS
# ============================================

RUN pgdgRpmUrl='https://yum.postgresql.org/10/redhat/rhel-7-x86_64/' && \
      pgdgRpmUrl+='pgdg-centos10-10-2.noarch.rpm' && \
      rpm -Uvh "${pgdgRpmUrl}" && \
      yum -y install postgresql10 postgresql10-server postgis23_10

# ============================================
#   Set up the base components of the image
# ============================================

# Important: This section is placed after setting up the system and installing
#            PostgreSQL and PostGIS so that changes to the image setup do not
#            cause the layers in the first section to be re-created.

# Inform about software versions being used inside the builder.
ENV POSTGRESQL_VERSION=10.4
ENV POSTGIS_VERSION=2.3

# Set labels used in OpenShift to describe the builder images.
LABEL io.k8s.description="An object-relational database management system \
with support for geographic objects" \
      io.k8s.display-name="PostgreSQL 10/PostGIS" \
      # Uncomment this if the service for the application that will run this
      # image will be exposed.
      # io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,sql,postgresql,postgis"

# ============================================
#   Set up the components of the image for running it on OpenShift Origin
# ============================================

# Note on building to run on OpenShift Origin:
#   In order to sccessfully run the image built by this Dockerfile on OpenShift
#   Origin, the ID of the user OpenShift Origin will runs the image as must be
#   assigned to argument variable OPENSHIFT_ORIGIN_USER_ID.
# 
#   To get this ID, a new OpenShift application must be created with the image
#   must be built by this packaging library using any OpenShift Origin using ID
#   and a S2I source repository containing a run script that prints the output
#   of the user it ran as (this can be done with command `id -u`). Then, the
#   logs of the pod that ran the application must be checked. (The complete
#   command to do this can be found at
#   https://hub.docker.com/r/adrianbartyczak/openshift-postgresql-10-postgis/.)
# 
#   The image built by this Dockerfile must then be rebuilt with the ID assigned
#   to argument variable OPENSHIFT_ORIGIN_USER_ID. (This can be done via option
#   `--build-arg OPENSHIFT_ORIGIN_USER_ID=<id>`.)
# 
#   Note that the user OpenShift Origin runs images as is the same across a
#   project.

ARG OPENSHIFT_ORIGIN_USER_ID=1027270000

# Note on the default user created by the base centos7 image:
#   The base-centos7 image creates a default user with name "default" and ID
#   1001 but it cannot be used in the container of the image built by this
#   Dockerfile in OpenShift Origin. The entry for this user in /etc/passwd is
#   the following:
#       default:x:1001:0:Default Application User:/opt/app-root/src:/sbin/nologin
#   To maintain run consistency between Docker and OpenShift Origin, this
#   Dockerfile sets up the image to run as a user with ID assigned to argument
#   variable OPENSHIFT_ORIGIN_USER_ID.

# ============================================
#   Set up PostgreSQL
# ============================================

# Manually create directory /var/lib/postgres and make it be owned by a user
# other than root. This is for the reason that the initdb executable must be
# executed by a user other than root.
RUN mkdir -p /var/lib/postgres && chown 1001:1001 /var/lib/postgres

# The user that owns the server process must have write permissions on
# /var/run/postgresql so the server can create a UNIX socket file for binding
# the address it will listen on.
RUN chown -R 1001:1001 /var/run/postgresql

# Switch to user 1001 because the initdb executable must be run "as the user
# that will own the server process, because the server needs to have access
# to the files and directories that initdb creates" (PostgreSQL documentation)
# and because the PostgreSQL server will be started to set up databases for the
# image to run on OpenShift Origin, once again requiring the process to be owned
# by the user that owns the data directory.
USER 1001

# Initialize PostgreSQL. Note: This cannot be done in an OpenShift S2I assembly
# script (unless the user it is run as has root access) because PostgreSQL
# databases must be set up for the image in the image build because only the
# image build has permission to change ownerships on files and directories that
# will be accessed by the PostgreSQL server and the initdb executable must of
# course be executed before then.
# Note: initdb creates a PostgreSQL role with the name of the system user it was
# executed as (in this case "default").
RUN /usr/pgsql-10/bin/initdb --locale en_US.UTF-8 -E UTF8 -D \
      /var/lib/postgres/data

# Temporarily start the PostgreSQL server and create (1) a database used as a
# template for creating PostGIS enabled databases and (2) the default database
# that will be connected to by the default PostgreSQL role.
RUN /usr/pgsql-10/bin/pg_ctl -D /var/lib/postgres/data -w start && \
      createdb template_postgis -E UTF-8 && \
      psql -d template_postgis -c 'CREATE EXTENSION postgis' && \
      psql -d template_postgis -c 'CREATE EXTENSION pgcrypto' && \
      psql -d template_postgis -c 'CREATE EXTENSION "uuid-ossp"' && \
      \
      # Manually create database "default". The reason for this is based on the
      # fact that OpenShift Origin runs an image as a user created by it. When
      # the psql executable is executed, it uses the name of the system user as
      # the name of the PostgreSQL role to connect as. If a role with this name
      # does not exist, PostgreSQL will show error "FATAL:  role
      # "<system_user_name>" does not exist". Furthermore, if in the uncommon
      # case the user executing the psql executable does not exist in the
      # operating system, PostgreSQL will show error "local user with ID
      # <id_of_system_user> does not exist". The user OpenShift Origin runs the
      # image as of course does not exist in the system and therefore has no
      # name. As a result, this Dockerfile instructs the image build invoked
      # with it to create a "psql" wrapper script (at the bottom of the next
      # section) that always connects as role "default". As the default role
      # used to connect as is "default" and psql uses the name of the role used
      # to connect as-as the name of the default database to connect to,
      # database "default" is created. (Note: Database "default" is created with
      # the PostGIS template database to illustrate the use of the PostGIS
      # template database).
      createdb default --owner=default --template='template_postgis' && \
      \
      /usr/pgsql-10/bin/pg_ctl -D /var/lib/postgres/data stop

# Configure PostgreSQL to allow access from all IPv4 addresses. Note: This step
# must be done after PostgreSQL has been initialized.
# RUN echo "host    all             all             0.0.0.0/0               md5" \
#       >>/var/lib/postgres/data/pg_hba.conf

# ============================================
#   Set up the PostgreSQL-related components of the image to successfully run it
#   on OpenShift Origin
# ============================================

USER root

# The user that runs the PostgreSQL server must be the owner of the data
# directory to access files in it.
RUN chown -R $OPENSHIFT_ORIGIN_USER_ID:$OPENSHIFT_ORIGIN_USER_ID \
      /var/lib/postgres/data

# The ownership of /var/run/postgresql must be change for the user OpenShift
# Origin will run the image built by this Dockerfile as for the same reason
# it was changed for the "default" user in the previous section.
RUN chown $OPENSHIFT_ORIGIN_USER_ID:$OPENSHIFT_ORIGIN_USER_ID \
      /var/run/postgresql

# For some reason, the base centos7 images includes binary /usr/bin/psql,
# however, the installed PostgreSQL includes file /usr/pgsql-10/bin/psql.
# Running "psql" runs /usr/bin/psql which does not use the same version as the 
# installed PostgreSQL package, resulting in a warning message. Therefore, it
# must be be overwritten to use /usr/pgsql-10/bin/psql.
# Additionally, as the user OpenShift Origin will run the image built by this
# Dockerfile does not exist in the system, running psql without specifying a
# user results in error "local user with ID <OPENSHIFT_ORIGIN_USER_ID> does not
# exist". For this reason, a wrapper script must be created to run psql as a
# default role.
RUN printf '\
#!/bin/bash\n\
\n\
/usr/pgsql-10/bin/psql -U default "${@}"\n\
\n\
' >/usr/bin/psql

# ============================================
#   Set up other components of the image for OpenShift Origin
# ============================================

# Make user OPENSHIFT_ORIGIN_USER_ID own /opt/app-root.
RUN chown -R $OPENSHIFT_ORIGIN_USER_ID:$OPENSHIFT_ORIGIN_USER_ID /opt/app-root

# ============================================
#   Set up the remaining components of the image
# ============================================

# Set the default user for the image. Note: This is only for running the image
# built by this Dockerfile as a plain Docker container and not with an OpenShift
# application as the user OpenShift Origin run images is a user created by the
# pod that runs the application.
USER $OPENSHIFT_ORIGIN_USER_ID

# Specify the ports the final image will expose.
# (Uncomment this if the service for the application that will run this image
# will be exposed.)
# EXPOSE 8080

# ============================================
#   Add OpenShift S2I build scripts to the image so it can be built using the
#   OpenShift S2I tool with S2I source files included in it
#   (Just for reference; see note)
# ============================================

# Copy the S2I scripts to /usr/libexec/s2i which is the location set for scripts
# in openshift/base-centos7 as io.openshift.s2i.scripts-url label.
# COPY ./.s2i/bin/ /usr/libexec/s2i

# Set the default CMD to print the usage of the S2I built image when it is run
# with "docker run".
# CMD ["/usr/libexec/s2i/usage"]

# Note on using /usr/libexec/s2i for S2I source files:
#   If the image built by this Dockerfile is built as an OpenShift S2I image,
#   using /usr/libexec/s2i for S2I source files is an alternative to using
#   a S2I source files repository. Note that if it is used, the container
#   of the S2I built image will execute only the script specified in the CMD
#   instruction and exit.
# 
#   Both the /usr/libexec/s2i directory and a S2I source files repository can
#   be used however. In this case, a S2I source files repository will override
#   the S2I /usr/libexec/s2i source files directory. This has the advantage of
#   building the image built by this Dockerfile as an S2I built image with or
#   without specifying a S2I source files repository.

