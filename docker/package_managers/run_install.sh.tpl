#!/bin/bash
#set -ex
echo start
# Resolve the docker tool path
DOCKER="%{docker_tool_path}"
DOCKER_FLAGS="%{docker_flags}"

if [[ -z "$DOCKER" ]]; then
    echo >&2 "error: docker not found; do you need to manually configure the docker toolchain?"
    exit 1
fi

# Setup tools and load utils
TO_JSON_TOOL="%{to_json_tool}"
source %{util_script}

# Load the image and remember its name
image_id=$(%{image_id_extractor_path} %{base_image_tar})
$DOCKER $DOCKER_FLAGS load -i %{base_image_tar}

cid=$($DOCKER $DOCKER_FLAGS run -di --privileged $image_id)
dir=$(dirname %{installables_tar})

$DOCKER $DOCKER_FLAGS attach $cid || true
echo >&2 "attach"
$DOCKER $DOCKER_FLAGS exec ${cid} bash -c "mkdir -p  /tmp/${dir}"
$DOCKER $DOCKER_FLAGS cp -L $(pwd)/%{installables_tar} ${cid}:/tmp/%{installables_tar}
$DOCKER $DOCKER_FLAGS cp -L $(pwd)/%{installer_script} ${cid}:/tmp/installer.sh
$DOCKER $DOCKER_FLAGS exec ${cid} bash -c "/tmp/installer.sh"
echo resetc
reset_cmd $image_id $cid %{output_image_name}
$DOCKER $DOCKER_FLAGS save %{output_image_name} > %{output_file_name}
$DOCKER $DOCKER_FLAGS rm $cid
