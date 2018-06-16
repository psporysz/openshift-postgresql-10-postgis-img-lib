
# Openshift-postgresql-10-postgis-img-lib

This is the Docker packaging library for image [adrianbartyczak/openshift-postgresql-10-postgis](https://hub.docker.com/r/adrianbartyczak/openshift-postgresql-10-postgis/).

## Build

Change to the directory of this packaging library and build it with the following command:

    docker build --build-arg OPENSHIFT_ORIGIN_USER_ID=<id> -t <image_name>:<image_tag> .

### Getting the OpenShift Origin user ID

1. Create a new application with an image built by this packaging library using any OpenShift Origin user ID and an S2I source repository containing a run script that prints the output of the user it ran as (this can be done with command `id -u`). *(The complete command to do this can be found at the image link provided.)*

2. Check the logs of the pod that ran the application.

## Usage

Please see the [S2I usage script](https://github.com/adrianbartyczak/openshift-postgresql-10-postgis-img-s2i/blob/master/.s2i/bin/usage) in the [S2I source repository for the image built by this packaging library](https://github.com/adrianbartyczak/openshift-postgresql-10-postgis-img-s2i/) for complete usage information.

## Sources

This project is based on [this tutorial](https://blog.openshift.com/create-s2i-builder-image/).

