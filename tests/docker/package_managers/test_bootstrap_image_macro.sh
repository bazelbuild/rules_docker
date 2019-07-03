#!/bin/bash

set -ex

trap __cleanup EXIT

#Clean up functions
__cleanup ()
{
  [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
  [[ -f "$TEST_BUILD_FILE" ]] && rm "$TEST_BUILD_FILE"
}

function die(){
  echo "$1"
  exit 1
}

PWD=$(pwd)
GIT_ROOT=$(git rev-parse --show-toplevel)

if [ "$PWD" != "$GIT_ROOT" ]; then
  echo "Please run this script from bazel root workspace"
  exit 1
fi

TEST_TARGET="tests/docker/package_managers:test_bootstrap_ubuntu"
TEST_DIR="tests/docker/package_managers/tmp_git"
TEST_STORE="$TEST_DIR/ubuntu/16_0_4/builds"
TEST_SCRIPT_CMD="./bootstrap_image.sh -t $TEST_TARGET"
DATE="20190301"

TEST_BUILD_FILE="tests/docker/package_managers/BUILD.bazel"
# Build new BUILD file with bootstrap_image_macro target
cat > "$TEST_BUILD_FILE" <<- EOM
load("//docker/package_managers:bootstrap_image.bzl", "bootstrap_image_macro")
bootstrap_image_macro(
    name = "test_bootstrap_ubuntu",
    date = "$DATE",
    image_tar = "//ubuntu:ubuntu_16_0_4_vanilla.tar",
    output_image_name = "ubuntu",
    packages = [
        "curl",
        "netbase",
    ],
    store_location = "$TEST_STORE",
)
EOM

# Create a Temporary store in this directory
mkdir -p "$TEST_STORE"

# Run Bazel build target for first time
bazel clean
OUTPUT=$($TEST_SCRIPT_CMD)

# Check if download_pkgs output was ran
EXPECTED_OUTPUT="*Running download_pkgs script*"
if [ "${OUTPUT/$EXPECTED_OUTPUT}" = "$OUTPUT" ] ; then
  die "Expected download_pkgs script to run. However it did not"
else
  echo "download_pkgs script ran as expected"
fi

# Test if downloaded pakcages.tar is copied to the store
PUT_FILE="$GIT_ROOT/$TEST_STORE/$DATE/packages.tar"
if [ ! -f "$PUT_FILE" ]; then
   die "Expected file $PUT_FILE to be present. However its not."
fi

# Run Bazel build target once again and this time download_pkgs script should
# not run
bazel clean
OUTPUT=$($TEST_SCRIPT_CMD)
# Check if download_pkgs output was ran
if [ "${OUTPUT/$EXPECTED_OUTPUT}" = "$OUTPUT" ] ; then
  echo "download_pkgs script did not run as expected"
else
  die "download_pkgs script ran. However it should not have!"
fi

