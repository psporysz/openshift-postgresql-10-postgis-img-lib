
# Openshift-postgresql-10-postgis-img-lib

This is the Docker packaging library for image [adrianbartyczak/openshift-postgresql-10-postgis](https://hub.docker.com/r/adrianbartyczak/openshift-postgresql-10-postgis/).

## Build

Change to the directory of this packaging library and build it with the following command:

    docker build --build-arg OPENSHIFT_ORIGIN_USER_ID=<id> -t <image_name>:<image_tag> .

### Getting the OpenShift Origin user ID

1. Create a new application with an image built by this packaging library using any OpenShift Origin user ID. *A command to do this can be found at the provided link above.*

2. Check the logs of the pod that ran the application.

## Note on S2I source files

The image built by this packaging library is built with S2I source files used when an S2I image build is invoked.

They are overridden by an S2I source repository when one is used with an S2I image build.

To create an S2I source repositry for this image, simply copy directory .s2i/ to a new repository.

## Usage

Please see [.s2i/bin/usage](.s2i/bin/usage) for complete usage information.

## Sources

This project is based on [this tutorial](https://blog.openshift.com/create-s2i-builder-image/).

