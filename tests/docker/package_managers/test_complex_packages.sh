#!/usr/bin/env bash

set -ex
TEST_BUILD_FILE="tests/docker/package_managers/BUILD.bazel"
OUTPUT_BASE="--output_base=/workspace/output_base"
BAZEL_FLAGS="--spawn_strategy=standalone"

function setup() {

  # Move contents to a subdirectory so that output base can be set to
  # /workspace/output_base
  mkdir rules_docker
  mv * rules_docker || true
  mv .bazelrc rules_docker
  cd rules_docker

  # Build new BUILD file with download_pkgs target
  cat > "$TEST_BUILD_FILE" <<- EOM
load("//docker/package_managers:download_pkgs.bzl", "download_pkgs")

download_pkgs(
    name = "test_complex_download_pkgs",
    image_tar = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    packages = [
        "curl",
        "netbase",
        "ca-certificates",
    ],
)
EOM

  # Setup container-diff
  curl -LO https://storage.googleapis.com/container-diff/latest/container-diff-linux-amd64 && chmod +x container-diff-linux-amd64
  mv container-diff-linux-amd64 container-diff
}

function run_download_pkgs() {
    # Run download_pkgs and grab the resulting installables tar file
    # We need to use a custom output_base as running install_pkgs requires
    # mounting files from the output_base onto the sibling container
    rm -f test_download_complex_pkgs.tar
    bazel $OUTPUT_BASE run $BAZEL_FLAGS //tests/docker/package_managers:test_complex_download_pkgs
    cp bazel-bin/tests/docker/package_managers/test_complex_download_pkgs.runfiles/io_bazel_rules_docker/tests/docker/package_managers/test_complex_download_pkgs.tar tests/docker/package_managers
}

function run_install_pkgs() {
    # Add install_pkgs target to generated BUILD file
    cat >> "$TEST_BUILD_FILE" <<- EOM
load("//docker/package_managers:install_pkgs.bzl", "install_pkgs")

install_pkgs(
    name = "test_complex_install_pkgs",
    image_tar = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    output_image_name = "test_complex_install_pkgs",
    installables_tar = ":test_complex_download_pkgs.tar",
)
EOM

    # Run install_pkgs and grab the build docker image tar
    rm -f tests/docker/package_managers/test_complex_install_pkgs.tar
    bazel $OUTPUT_BASE build $BAZEL_FLAGS //tests/docker/package_managers:test_complex_install_pkgs
    cp bazel-bin/tests/docker/package_managers/test_complex_install_pkgs.tar tests/docker/package_managers
}

function run_build_dockerfile_and_compare() {
    # Generate a Dockerfile with the same apt packages and build the docker image
    bazel $OUTPUT_BASE build $BAZEL_FLAGS @ubuntu1604//:ubuntu1604_vanilla.tar
    TEST_DOCKER_FILE="tests/docker/package_managers/Dockerfile.test"
    cat > "$TEST_DOCKER_FILE" <<- EOM
FROM bazel:ubuntu1604_vanilla

RUN apt-get update && \
  apt-get install --no-install-recommends -y curl netbase ca-certificates
EOM
    docker rmi rules_docker/test:test || true
    cid=$(docker build -q -t rules_docker/test:test - < $TEST_DOCKER_FILE)

    # Compare it with the tar file built with install_pkgs using container diff
    # TODO(selgamal): actually parse out container-diff output once it's fixed
    ./container-diff diff tests/docker/package_managers/test_complex_install_pkgs.tar daemon://rules_docker/test:test -j
}

# Call functions above. 1st parameter must be a function defined above
# (simple approach to make migration easy for these tests)
$1

