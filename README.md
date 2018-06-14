
# Openshift-postgresql-10-postgis

This is the Docker packaging library for image [adrianbartyczak/openshift-postgresql-10-postgis](https://hub.docker.com/r/adrianbartyczak/openshift-postgresql-10-postgis/).

## Build

Change to the directory of this packaging library and build it with the following command:

    docker build --build-arg OPENSHIFT_ORIGIN_USER_ID=<id> -t <image_name>:<image_tag> .

See section [Important information on building for OpenShift Origin](#important-information-on-building-for-openshift-origin) for instructions on getting the OpenShift Origin user ID.

Please see the [S2I usage script](https://github.com/adrianbartyczak/openshift-postgresql-10-postgis-s2i/blob/master/.s2i/bin/usage) in the respective S2I scripts repository for complete usage information.

## Important information on building for OpenShift Origin

OpenShift Origin runs a Docker image as a default user created by it, overriding the user the image was instructed to run as. This makes the USER instruction useless and is an obstacle in building Docker images to run on OpenShift Origin.

The ID of the user OpenShift Origin runs an image as cannot be known until after the it has run the image (there may be a solution for this but I have not found it). Note that the user OpenShift Origin runs images as is the same across pods in a datacenter but not the same across pods in different datacenters (or possibly nodes?).

In order to successfully run the image built by this library on OpenShift, it must be set up to run as the same user  OpenShift Origin will run it as. This user is specified by ID and this ID is assigned to argument variable `OPENSHIFT_ORIGIN_USER_ID` in the Dockerfile. To get the correct OpenShift Origin user ID, a new application must be created with the pre-built image ([adrianbartyczak/openshift-postgresql-10-postgis](https://hub.docker.com/r/adrianbartyczak/openshift-postgresql-10-postgis/)) and run. After it fails or succeeds, the ID of the user the pod ran the application as must be checked for in the pod's logs. It will be printed if the [S2I source repository for this image](https://github.com/adrianbartyczak/openshift-postgresql-10-postgis-s2i/) was used when a new application was invoked with the image. The command to invoke a new application with this S2I source repository can be found at the Docker Hub page of the pre-built image.

Once the correct user ID is retrieved, this packaging library must be rebuilt with it and the resulting image must be pushed to Docker Hub and used when invoking a new application.

## Sources

This project is based on [this tutorial](https://blog.openshift.com/create-s2i-builder-image/).

