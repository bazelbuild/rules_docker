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

# Create a docker volume containing the installer script and the
# installables TAR file.
#
# Note that we cannot mount local files and directories
# directly into the container, since it doesn't work correctly
# in docker-in-docker setups.  In docker-in-docker setups, we
# are running in a container while the docker daemon is running
# on a host.  Mounting directories is done from the perspective
# of the host and not our container.
#
# To get around this, we create a named volume and copy our files
# to the named volume.

# Prepare directory structure. 'docker cp' will not create
# intermediate paths.
tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT
mkdir -p $(dirname $tmpdir/%{installables_tar})
cp -L $(pwd)/%{installables_tar} $tmpdir/%{installables_tar}
cp -L $(pwd)/%{installer_script} $tmpdir/installer.sh
# Temporarily create a container sowe can mount the named volume
# and copy files.
vid=$($DOCKER volume create)
cid=$($DOCKER create -v $vid:/tmp/pkginstall $image_id)
for f in $tmpdir/*; do
    $DOCKER cp $f $cid:/tmp/pkginstall
done
$DOCKER rm $cid

cid=$($DOCKER run -d -v $vid:/tmp/pkginstall --privileged $image_id /tmp/pkginstall/installer.sh)

$DOCKER attach $cid || true

reset_cmd $image_id $cid %{output_image_name}
$DOCKER save %{output_image_name} > %{output_file_name}
$DOCKER rm $cid
$DOCKER volume rm $vid
