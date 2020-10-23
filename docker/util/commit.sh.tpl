#!/usr/bin/env bash

set -e

# Setup tools and load utils
TO_JSON_TOOL="%{to_json_tool}"
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

reset_cmd $image_id $id %{output_image}
$DOCKER $DOCKER_FLAGS save %{output_image} -o %{output_tar}
$DOCKER $DOCKER_FLAGS rm $id
