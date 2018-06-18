
# Openshift-postgresql-10-postgis-img-lib

This is the Docker packaging library for image [adrianbartyczak/openshift-postgresql-10-postgis](https://hub.docker.com/r/adrianbartyczak/openshift-postgresql-10-postgis/).

## Build

Change to the directory of this packaging library and build it with the following command:

    docker build --build-arg OPENSHIFT_ORIGIN_USER_ID=<id> -t <image_name>:<image_tag> .

### Getting the OpenShift Origin user ID

1. Create a new application with an image built by this packaging library using any OpenShift Origin user ID. *The command to do this can be found at the image link provided.*

2. Check the logs of the pod that ran the application.

## OpenShift S2I source files

The image built by this packaging library contains S2I source files that will be used when a new application is invoked.

If a S2I source repository is used when inoking a new application with the image built by this packaging library, the S2I source repository will override the S2I source files in the image.

To create a S2I source repositry for this image, simply copy the .s2i directory to a new repository.

## Usage

Please see the [.s2i/bin/usage](.s2i/bin/usage) for complete usage information.

## Sources

This project is based on [this tutorial](https://blog.openshift.com/create-s2i-builder-image/).

