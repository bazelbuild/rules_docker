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

# Run the builder image.
cid=$($DOCKER run -w="/" -d --privileged $image_id sh -c $'%{download_commands}')
$DOCKER attach $cid
$DOCKER cp $cid:%{installables}_packages.tar %{output}
$DOCKER cp $cid:%{installables}_metadata.csv %{output_metadata}
# Cleanup
$DOCKER rm $cid
