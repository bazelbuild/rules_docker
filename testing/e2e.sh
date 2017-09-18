#!/bin/bash -e

# Copyright 2015 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Must be invoked from the root of the repo.
ROOT=$PWD

function fail() {
  echo "FAILURE: $1"
  exit 1
}

function CONTAINS() {
  local complete="${1}"
  local substring="${2}"

  echo "${complete}" | grep -Fsq -- "${substring}"
}

function EXPECT_CONTAINS() {
  local complete="${1}"
  local substring="${2}"
  local message="${3:-Expected '${substring}' not found in '${complete}'}"

  echo Checking "$1" contains "$2"
  CONTAINS "${complete}" "${substring}" || fail "$message"
}

function stop_containers() {
  docker rm -f $(docker ps -aq) > /dev/null 2>&1 || /bin/true
}

# Clean up any containers [before] we start.
stop_containers
trap "stop_containers" EXIT

function test_top_level() {
  local directory=$(mktemp -d)

  cd "${directory}"

  cat > "BUILD" <<EOF
package(default_visibility = ["//visibility:private"])

load(
  "@io_bazel_rules_docker//docker:docker.bzl",
  "docker_build",
)

docker_build(
  name = "pause_based",
  base = "@pause//image",
  workdir = "/tmp",
)
EOF

  cat > "WORKSPACE" <<EOF
workspace(name = "top_level")

local_repository(
    name = "io_bazel_rules_docker",
    path = "$ROOT",
)

load(
  "@io_bazel_rules_docker//docker:docker.bzl",
  "docker_repositories", "docker_pull"
)
docker_repositories()

docker_pull(
  name = "pause",
  registry = "gcr.io",
  repository = "google-containers/pause",
  tag = "2.0",
)
EOF

  bazel build --verbose_failures --spawn_strategy=standalone :pause_based
}


function clear_docker() {
  docker rmi -f $(docker images -aq) || true
}

function test_bazel_run_docker_build_clean() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_build", "docker/testdata/...")');
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_bundle_clean() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_bundle", "docker/testdata/...")');
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_import_clean() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_import", "docker/testdata/...")');
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_build_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_build", "docker/testdata/...")');
  do
    bazel run $target
  done
}

function test_bazel_run_docker_bundle_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_bundle", "docker/testdata/...")');
  do
    bazel run $target
  done
}

function test_bazel_run_docker_import_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_import", "docker/testdata/...")');
  do
    bazel run $target
  done
}

function test_py_image() {
  cd "${ROOT}"
  clear_docker
  cat > output.txt <<EOF
$(bazel run docker/testdata:py_image)
EOF
  EXPECT_CONTAINS "$(cat output.txt)" "First: 4"
  EXPECT_CONTAINS "$(cat output.txt)" "Second: 5"
  EXPECT_CONTAINS "$(cat output.txt)" "Third: 6"
  EXPECT_CONTAINS "$(cat output.txt)" "Fourth: 7"
  rm -f output.txt
}

function test_cc_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run docker/testdata:cc_image)" "Hello World"
}

function test_go_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run docker/testdata:go_image)" "Hello, world!"
}

function test_java_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run docker/testdata:java_image)" "Hello World"
}

function test_java_bin_as_lib_image() {
  cd "${ROOT}"
  clear_docker
  bazel run docker/testdata:java_bin_as_lib_image
  docker run -ti --rm bazel/docker/testdata:java_bin_as_lib_image
}

function test_war_image() {
  cd "${ROOT}"
  clear_docker
  bazel build docker/testdata:war_image.tar
  docker load -i bazel-bin/docker/testdata/war_image.tar
  ID=$(docker run -d -p 8080:8080 bazel/docker/testdata:war_image)
  sleep 5
  EXPECT_CONTAINS "$(curl localhost:8080)" "Hello World"
  docker rm -f "${ID}"
}

test_top_level
test_bazel_run_docker_build_clean
test_bazel_run_docker_bundle_clean
test_bazel_run_docker_import_clean
test_bazel_run_docker_build_incremental
test_bazel_run_docker_bundle_incremental
test_bazel_run_docker_import_incremental
test_py_image
test_cc_image
# test_go_image
test_java_image
test_java_bin_as_lib_image
test_war_image
