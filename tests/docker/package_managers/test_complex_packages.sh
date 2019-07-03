#!/bin/bash

set -ex

#Clean up functions
cleanup()
{
    [[ -f "$TEST_BUILD_FILE"  ]] && rm  "$TEST_BUILD_FILE"
      [[ -f "$TEST_DOCKER_FILE"  ]] && rm  "$TEST_DOCKER_FILE"
}

trap cleanup EXIT

TEST_BUILD_FILE="tests/docker/package_managers/BUILD.bazel"
# Build new BUILD file with download_pkgs target
cat > "$TEST_BUILD_FILE" <<- EOM
load("//docker/package_managers:download_pkgs.bzl", "download_pkgs")

download_pkgs(
    name = "test_complex_download_pkgs",
    image_tar = "//ubuntu:ubuntu_16_0_4_vanilla",
    packages = [
        "curl",
        "netbase",
        "ca-certificates",
    ],
)
EOM

# Run download_pkgs and grab the resulting installables tar file
rm -f test_download_complex_pkgs.tar
bazel run //tests/docker/package_managers:test_complex_download_pkgs
cp  bazel-bin/tests/docker/package_managers/test_complex_download_pkgs.runfiles/base_images_docker/tests/docker/package_managers/test_complex_download_pkgs.tar tests/docker/package_managers

# Add install_pkgs target to generated BUILD file
cat >> "$TEST_BUILD_FILE" <<- EOM
load("//docker/package_managers:install_pkgs.bzl", "install_pkgs")

install_pkgs(
    name = "test_complex_install_pkgs",
    image_tar = "//ubuntu:ubuntu_16_0_4_vanilla.tar",
    output_image_name = "test_complex_install_pkgs",
    installables_tar = ":test_complex_download_pkgs.tar",
)
EOM

# Run install_pkgs and grab the build docker image tar
rm -f tests/docker/package_managers/test_complex_install_pkgs.tar
bazel build //tests/docker/package_managers:test_complex_install_pkgs
cp bazel-bin/tests/docker/package_managers/test_complex_install_pkgs.tar tests/docker/package_managers

# Generate a Dockerfile with the same apt packages and build the docker image
bazel build //ubuntu:ubuntu_16_0_4_vanilla
TEST_DOCKER_FILE="tests/docker/package_managers/Dockerfile.test"
cat > "$TEST_DOCKER_FILE" <<- EOM
FROM bazel/ubuntu:ubuntu_16_0_4_vanilla

RUN apt-get update && \
  apt-get install --no-install-recommends -y curl netbase ca-certificates
EOM

cid=$(docker build -q - < $TEST_DOCKER_FILE)

# Compare it with the tar file built with install_pkgs using container diff
# TODO(selgamal): actually parse out container-diff output once it's fixed
container-diff diff tests/docker/package_managers/test_complex_install_pkgs.tar daemon://"$cid" -j

