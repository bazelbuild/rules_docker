#!/usr/bin/env bash
set -o errexit

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
"$DOCKER" $DOCKER_FLAGS load -i %{base_image_tar}

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
log=$(mktemp)
trap "rm -rf $tmpdir $log" EXIT
mkdir -p $(dirname $tmpdir/%{installables_tar})
cp -L $(pwd)/%{installables_tar} $tmpdir/%{installables_tar}
cp -L $(pwd)/%{installer_script} $tmpdir/installer.sh

(
# Temporarily create a container so we can mount the named volume
# and copy files.  It's okay if /bin/true doesn't exist inside the
# image; we are never going to run the image anyways.
vid=$("$DOCKER" $DOCKER_FLAGS volume create)
cid=$("$DOCKER" $DOCKER_FLAGS create -v $vid:/tmp/pkginstall $image_id /bin/true)
for f in $tmpdir/*; do
    "$DOCKER" $DOCKER_FLAGS cp $f $cid:/tmp/pkginstall
done
"$DOCKER" $DOCKER_FLAGS rm $cid

cid=$("$DOCKER" $DOCKER_FLAGS run -d -v $vid:/tmp/pkginstall --privileged $image_id /tmp/pkginstall/installer.sh)

"$DOCKER" $DOCKER_FLAGS attach $cid || true

reset_cmd $image_id $cid %{output_image_name}
"$DOCKER" $DOCKER_FLAGS save %{output_image_name} > %{output_file_name}
"$DOCKER" $DOCKER_FLAGS rm $cid
"$DOCKER" $DOCKER_FLAGS volume rm $vid
) > "$log" 2>&1

if (( $? )); then
    cat "$log"
fi