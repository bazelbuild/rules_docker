#!/bin/bash
set -ex

# Resolve the docker tool path
DOCKER="%{docker_tool_path}"

if [[ -z "$DOCKER" ]]; then
    echo >&2 "error: docker not found; do you need to manually configure the docker toolchain?"
    exit 1
fi

# Setup tools and load utils
TO_JSON_TOOL="%{to_json_tool}"
source %{util_script}

# Load the image and remember its name
image_id=$(%{image_id_extractor_path} %{base_image_tar})
$DOCKER load -i %{base_image_tar}


cid=$($DOCKER run -d -v $(pwd)/%{installables_tar}:/tmp/%{installables_tar} -v $(pwd)/%{installer_script}:/tmp/installer.sh --privileged $image_id /tmp/installer.sh)

$DOCKER attach $cid || true

reset_cmd $image_id $cid %{output_image_name}
$DOCKER save %{output_image_name} > %{output_file_name}
$DOCKER rm $cid
