#!/bin/bash

set -ex

# Resolve the docker tool path
DOCKER="%{docker_tool_path}"

if [[ -z "$DOCKER" ]]; then
    echo >&2 "error: docker not found; do you need to manually configure the docker toolchain?"
    exit 1
fi

# Load the image and remember its name
image_id=$(%{image_id_extractor_path} %{image_tar})
$DOCKER load -i %{image_tar}

id=$($DOCKER run -d %{docker_run_flags} $image_id %{commands})

$DOCKER wait $id
$DOCKER cp $id:%{extract_file} %{output}
$DOCKER rm $id
