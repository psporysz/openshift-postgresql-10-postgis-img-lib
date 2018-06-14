# 
# File:
#   Dockerfile
# 
# Description:
#   The Dockerfile for image adrianbartyczak/openshift-postgresql-10-postgis
# 

FROM openshift/base-centos7

# ============================================
#   Set up the system and install PostgreSQL and PostGIS
# ============================================

# Enable the EPEL repository as it is needed by the dependecies of PostGIS.
RUN yum -y install epel-release
# Import the EPEL GPG-key to ensure that package integrity has not been
# compromised.
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

RUN pgdgRpmUrl='https://yum.postgresql.org/10/redhat/rhel-7-x86_64/' && \
      pgdgRpmUrl+='pgdg-centos10-10-2.noarch.rpm' && \
      rpm -Uvh "${pgdgRpmUrl}" && \
      yum -y install postgresql10 postgresql10-server postgis23_10

# ============================================
#   Set up the image
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
      # Uncomment this if the service for this container will be exposed.
      # io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,sql,postgresql,postgis"

# IMPORTANT NOTE ON OPENSHIFT ORIGIN USER:
#   On OpenShift Origin, this image runs as a user created by OpenShift Origin
#   rather than the one set in this Dockerfile. The ID of this user is long
#   (e.g. 1027270000, 1003330000). In order to sccessfully run the image built
#   by this Dockerfile on OpenShift Origin, the correct user ID must be assigned
#   to argument variable OPENSHIFT_ORIGIN_USER_ID in this Dockerfile.
# 
#   If the OpenShift pod that ran the image built by this Dockerfile ran
#   successfully, the ID of the user it ran as matched the value of argument
#   variable OPENSHIFT_ORIGIN_USER_ID and nothing needs to be done. If it failed
#   to run, it will have have a status like "CrashLoopBackOff" or possibly
#   "Error" because it was unable to access a file in /var/lib/postgres/data
#   (likely postgresql.conf) (this will be shown in the logs) as the user it ran
#   as did not have permission to.
# 
#   To get this user ID, an OpenShift application must be created with an image
#   built by this Dockerfile and a S2I source repository that includes a run
#   script which prints the output of command `id -u`. (The command to do this
#   simply invokes a new application using the respective base S2I scripts
#   repository for this project. This command can be found at
#   https://hub.docker.com/r/adrianbartyczak/openshift-postgresql-10-postgis/).
#   Once the application has been created, the output of command `id -u` should
#   be checked for in the logs of the pod. This output is the ID of the user
#   the OpenShift pod ran as. The image built by the packaging library of this
#   Dockerfile must then be rebuilt with option
#   `--build-arg OPENSHIFT_ORIGIN_USER_ID=<id>`, pushed to Docker Hub and used
#   to invoke a new application.
# 
#   Note that the user OpenShift Origin pods run as is consistent across builds
#   and new applications but does change across datacenters (possibly across
#   nodes?).

# NOTE ON THE DEFAULT USER CREATED BY THE BASE CENTOS7 IMAGE:
#   The base-centos7 image creates a default user with name "default" and ID
#   1001 but it can only be used by a container of this image when it is
#   run with Docker. The entry for this user in /etc/passwd is the following:
#       default:x:1001:0:Default Application User:/opt/app-root/src:/sbin/nologin
#   To maintain run consistency between Docker and OpenShift Origin, this
#   Dockerfile runs the container as user with ID assigned to argument variable
#   OPENSHIFT_ORIGIN_USER_ID.

# Set the OpenShift Origin User ID default value.
ARG OPENSHIFT_ORIGIN_USER_ID=1027270000

# ============================================
#   Add OpenShift S2I build scripts to the image (just for reference; see note)
# ============================================

# Copy the S2I scripts to /usr/libexec/s2i which is the location set for scripts
# in openshift/base-centos7 as io.openshift.s2i.scripts-url label.
# COPY ./.s2i/bin/ /usr/libexec/s2i

# Set the default CMD to print the usage of the image when it is run with
# "docker run".
# CMD ["/usr/libexec/s2i/usage"]

# NOTE ON COPYING S2I SCRIPTS TO /usr/libexec/s2i:
#   The COPY command above does not make the image ready-to-run on OpenShift
#   Origin without specifying a S2I source repository. When S2I source files are
#   copied to /usr/libexec/s2i and an application is created without a S2I
#   source repository (i.e. just the image itself), the S2I build does not run
#   the "run" script, exits right away and runs the "usage" script (if one is
#   specified with the CMD command). When S2I source files are copied to
#   /usr/libexec/s2i and a new application is created with a S2I source
#   repository, however, the S2I source repository overrides the S2I source
#   files in /usr/libexec/s2i. Therefore, it is uncertain what the purpose of
#   copying S2I source files to /usr/libexec/s2i is as a S2I source repsoitory
#   must always be provided anyways.

# ============================================
#   Set up the user files and directories for the container
# ============================================

# Make user OPENSHIFT_ORIGIN_USER_ID own /opt/app-root.
RUN chown -R $OPENSHIFT_ORIGIN_USER_ID:$OPENSHIFT_ORIGIN_USER_ID /opt/app-root

# ============================================
#   Set up PostgreSQL
# ============================================

# Manually create directory /var/lib/postgres and make it owned by user
# "postgres" because the initdb binary must be run as user "postgres" (per
# PostgreSQL rules) and therefore will not have the permissions needed to create
# directory /var/lib/postgres.
RUN mkdir -p /var/lib/postgres && chown postgres:postgres /var/lib/postgres

# The PostgreSQL initialization (via the init binary) and other PostgreSQL
# operations requiring write permissions on postgres directories must be run as
# user "postgres".
USER postgres

# Initialize the PostgreSQL database. Note: This must be done in the Dockerfile
# rather than an S2I assembly script because the initdb binary must be run as
# "postgres" and the S2I assembly script runs as the default user.
RUN /usr/pgsql-10/bin/initdb --locale en_US.UTF-8 -E UTF8 -D \
      /var/lib/postgres/data

# Configure PostgreSQL to allow access from all IPv4 addresses. Note: This step
# must be done after running initdb.
# RUN echo "host    all             all             0.0.0.0/0               md5" \
#       >>/var/lib/postgres/data/pg_hba.conf

# Temporarily start the postgresql server and create (1) a database used as a
# template for creating postgis enabled databases and (2) a database and role
# for connecting to the server as the default user.
RUN /usr/pgsql-10/bin/pg_ctl -D /var/lib/postgres/data -w start && \
      createdb template_postgis -E UTF-8 && \
      psql -d template_postgis -c 'CREATE EXTENSION postgis' && \
      psql -d template_postgis -c 'CREATE EXTENSION pgcrypto' && \
      psql -d template_postgis -c 'CREATE EXTENSION "uuid-ossp"' && \
      \
      # The database role "default" must be created because when psql is run,
      # PostgreSQL uses the name of the system user to connect to the database
      # and if a role with the same name does not exist, it will throw an error
      # which reads "FATAL:  role "default" does not exist".
      createuser default --superuser && \
      \
      # Additionally, create database "default" because if psql is run without
      # specifying a database, PostgreSQL will use the name of the system user
      # as the name of the default database to connect to, which will likely not
      # exist.
      createdb default --owner=default --template='template_postgis' && \
      \
      /usr/pgsql-10/bin/pg_ctl -D /var/lib/postgres/data stop

USER root

# The user that runs the PostgreSQL server must be the owner of
# /var/lib/postgres/data. This is for the reason of having permissions to write
# to files in the directory.
RUN chown -R $OPENSHIFT_ORIGIN_USER_ID:$OPENSHIFT_ORIGIN_USER_ID \
			/var/lib/postgres/data

# In order for PostgreSQL to bind addresses when the server is started by the
# default user, the default user must have write permissions on
# /var/run/postgresql.
RUN chown $OPENSHIFT_ORIGIN_USER_ID:$OPENSHIFT_ORIGIN_USER_ID \
			/var/run/postgresql

# For some reason, the base centos7 images includes binary /usr/bin/psql,
# however, the installed PostgreSQL includes file /usr/pgsql-10/bin/psql.
# Running "psql" runs /usr/bin/psql which does not use the same version as the 
# installed PostgreSQL package, resulting in a warning message. Therefore, it
# must be be overwritten to use /usr/pgsql-10/bin/psql.
# Additionally, as the OpenShift Origin container user does not exist in the
# system, running psql without specifying a user results in error "local user
# with ID <OPENSHIFT_ORIGIN_USER_ID> does not exist". For this reason, a wrapper
# script must be created to run psql as user "default" by default.
RUN echo -e '#!/bin/bash\n\n/usr/pgsql-10/bin/psql -U default "${@}"\n' \
      >/usr/bin/psql

# ============================================
#   Set up the final components of the container
# ============================================

# Set the default user for the image.
USER $OPENSHIFT_ORIGIN_USER_ID

# Specify the ports the final image will expose.
# (Uncomment if the service for this container will be exposed.)
# EXPOSE 8080

