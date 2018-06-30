
# Openshift-postgresql-10-postgis-img-lib

This is the Docker packaging library for image [adrianbartyczak/openshift-postgresql-10-postgis](https://hub.docker.com/r/adrianbartyczak/openshift-postgresql-10-postgis/).

## Build

Change to the directory of this packaging library and run the following command:

    docker build --build-arg OPENSHIFT_ORIGIN_USER_ID=<id> -t <image_name>:<image_tag> .

### Getting the OpenShift Origin user ID

1. Build this packaging library with any OpenShift Origin user ID.

2. Invoke a new application with the built image.

*Note: A command to accomplish the first two steps can be found at the provided link above.*

3. Check the logs of the pod that ran the application.

## Note on included S2I source files

The image built by this packaging library is built with S2I source files. *These S2I source files are used in an S2I image build.*

If an S2I source repository is used with an S2I image build invoked with the image, the S2I source files in the image will be overridden.

To create an S2I source repository with the correct S2I source files for the image built by this packaging library for an S2I image build invoked with the image built by this packaging library, simply copy the *.s2i/* directory to a new repository.

## Usage

Please see [.s2i/bin/usage](.s2i/bin/usage) for complete usage information.

## Sources

This project is based on [this tutorial](https://blog.openshift.com/create-s2i-builder-image/).

