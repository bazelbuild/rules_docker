#!/bin/bash

set -ex

# Load utils
source %{util_script}

# Resolve the docker tool path
DOCKER="%{docker_tool_path}"
DOCKER_FLAGS="%{docker_flags}"

if [[ -z "$DOCKER" ]]; then
    echo >&2 "error: docker not found; do you need to manually configure the docker toolchain?"
    exit 1
fi

# Load the image and remember its name
image_id=$(%{image_id_extractor_path} %{image_tar})
$DOCKER $DOCKER_FLAGS load -i %{image_tar}

id=$($DOCKER $DOCKER_FLAGS run -d %{docker_run_flags} $image_id %{commands})
# Actually wait for the container to finish running its commands
retcode=$($DOCKER $DOCKER_FLAGS wait $id)
# Trigger a failure if the run had a non-zero exit status
if [ $retcode != 0 ]; then
  $DOCKER $DOCKER_FLAGS logs $id && false
fi
OUTPUT_IMAGE_TAR="%{output_layer_tar}.image.tar"
reset_cmd $image_id $id %{output_image}
$DOCKER $DOCKER_FLAGS save %{output_image} -o $OUTPUT_IMAGE_TAR
$DOCKER $DOCKER_FLAGS rm $id
$DOCKER $DOCKER_FLAGS rmi %{output_image}

%{image_last_layer_extractor_path} $OUTPUT_IMAGE_TAR %{output_layer_tar} %{output_diff_id}

rm $OUTPUT_IMAGE_TAR




