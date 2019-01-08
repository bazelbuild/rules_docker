#!/usr/bin/env bash
set -e
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
CONTAINER_IMAGE_TARGETS_QUERY="
bazel query 'kind(\"container_image\", \"testdata/...\") except
    (\"//testdata:py3_image_base_with_custom_run_flags\" union
    \"//testdata:java_image_base_with_custom_run_flags\" union
    \"//testdata:war_image_base_with_custom_run_flags\")'
"

function fail() {
  echo "FAILURE: $1"
  exit 1
}

function CONTAINS() {
  local complete="${1}"
  local substring="${2}"

  echo "${complete}" | grep -Fsq -- "${substring}"
}

function COUNT() {
  local complete="${1}"
  local substring="${2}"

  echo "${complete}" | grep -Fso -- "${substring}" | wc -l
}

function EXPECT_CONTAINS() {
  local complete="${1}"
  local substring="${2}"
  local message="${3:-Expected '${substring}' not found in '${complete}'}"

  echo Checking "$1" contains "$2"
  CONTAINS "${complete}" "${substring}" || fail "$message"
}

function EXPECT_CONTAINS_ONCE() {
  local complete="${1}"
  local substring="${2}"
  local count=$(COUNT "${complete}" "${substring}")

  echo Checking "$1" contains "$2" exactly once
  if [[ count -ne "1" ]]; then
    fail "${3:-Expected '${substring}' found ${count} in '${complete}'}"
  fi
}

function EXPECT_NOT_CONTAINS() {
  local complete="${1}"
  local substring="${2}"
  local message="${3:-Expected '${substring}' found in '${complete}'}"

  echo Checking "$1" does not contain "$2"
  ! (CONTAINS "${complete}" "${substring}") || fail "$message"
}

function stop_containers() {
  docker rm -f $(docker ps -aq) > /dev/null 2>&1 || builtin true
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

  bazel build --verbose_failures --spawn_strategy=standalone --toolchain_resolution_debug :pause_based
}


function clear_docker() {
  docker rmi -f $(docker images -aq) || true
  stop_containers
}

function test_bazel_build_then_run_docker_build_clean() {
  cd "${ROOT}"
  for target in $(eval $CONTAINER_IMAGE_TARGETS_QUERY);
  do
    clear_docker
    bazel build $target
    # Replace : with /
    ./bazel-bin/${target/://}
  done
}

function test_bazel_run_docker_build_clean() {
  cd "${ROOT}"
  for target in $(eval $CONTAINER_IMAGE_TARGETS_QUERY);
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_bundle_clean() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_bundle", "testdata/...")');
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_import_clean() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_import", "testdata/...")');
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_build_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(eval $CONTAINER_IMAGE_TARGETS_QUERY);
  do
    bazel run $target
  done
}

function test_bazel_run_docker_bundle_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_bundle", "testdata/...")');
  do
    bazel run $target
  done
}

function test_bazel_run_docker_import_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_import", "testdata/...")');
  do
    bazel run $target
  done
}

function test_py_image() {
  cd "${ROOT}"
  clear_docker
  cat > output.txt <<EOF
$(bazel run "$@" tests/docker/python:py_image)
EOF
  EXPECT_CONTAINS "$(cat output.txt)" "First: 4"
  EXPECT_CONTAINS "$(cat output.txt)" "Second: 5"
  EXPECT_CONTAINS "$(cat output.txt)" "Third: 6"
  EXPECT_CONTAINS "$(cat output.txt)" "Fourth: 7"
  rm -f output.txt
}

function test_py_image_complex() {
  cd "${ROOT}"
  clear_docker
  cat > output.txt <<EOF
$(bazel run "$@" testdata:py_image_complex)
EOF
  EXPECT_CONTAINS "$(cat output.txt)" "Calling from main module: through py_image_complex_library: Six version: 1.11.0"
  EXPECT_CONTAINS "$(cat output.txt)" "Calling from main module: through py_image_complex_library: Addict version: 2.1.2"
  rm -f output.txt
}

function test_py3_image_with_custom_run_flags() {
  cd "${ROOT}"
  clear_docker
  cat > output.txt <<EOF
$(bazel run "$@" testdata:py3_image_with_custom_run_flags)
EOF
  EXPECT_CONTAINS "$(cat output.txt)" "First: 4"
  EXPECT_CONTAINS "$(cat output.txt)" "Second: 5"
  EXPECT_CONTAINS "$(cat output.txt)" "Third: 6"
  EXPECT_CONTAINS "$(cat output.txt)" "Fourth: 7"
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/py3_image_with_custom_run_flags)" "-i --rm --network=host -e ABC=ABC"
  rm -f output.txt
}

function test_cc_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" tests/docker/cc:cc_image)" "Hello World"
}

function test_cc_binary_as_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:cc_binary_as_image)" "Hello World"
}

function test_cc_image_wrapper() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:cc_image_wrapper)" "Hello World"
}

function test_launcher_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:launcher_image)" "Launched via launcher!"
}

function test_go_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" tests/docker/go:go_image)" "Hello, world!"
}

function test_go_image_busybox() {
  cd "${ROOT}"
  clear_docker
  bazel run -c dbg tests/docker/go:go_image -- --norun
  local number=$RANDOM
  EXPECT_CONTAINS "$(docker run -ti --rm --entrypoint=sh bazel/tests/docker/go:go_image -c \"echo aa${number}bb\")" "aa${number}bb"
}

function test_go_image_with_tags() {
  cd "${ROOT}"
  EXPECT_CONTAINS "$(bazel query //tests/docker/go:go_image)" "//tests/docker/go:go_image"
  EXPECT_CONTAINS "$(bazel query 'attr(tags, tag1, //tests/docker/go:go_image)')" "//tests/docker/go:go_image"
  EXPECT_CONTAINS "$(bazel query 'attr(tags, tag2, //tests/docker/go:go_image)')" "//tests/docker/go:go_image"
  EXPECT_NOT_CONTAINS "$(bazel query 'attr(tags, other_tag, //tests/docker/go:go_image)')" "//tests/docker/go:go_image"
  echo yay
}

function test_java_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:java_image)" "Hello World"
}

function test_java_partial_entrypoint_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:java_partial_entrypoint_image examples.images.Binary)" "Hello World"
}

function test_java_image_with_custom_run_flags() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:java_image_with_custom_run_flags)" "Hello World"
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/java_image_with_custom_run_flags)" "-i --rm --network=host -e ABC=ABC"
}

function test_java_sandwich_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:java_sandwich_image)" "Hello World"
}

function test_java_simple_image() {
  cd "${ROOT}"
  clear_docker
  bazel run tests/docker/java:simple_java_image
  docker run -ti --rm bazel/tests/docker/java:simple_java_image
}

function test_java_image_arg_echo() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS_ONCE "$(bazel run "$@" testdata:java_image_arg_echo)" "arg0"
  EXPECT_CONTAINS_ONCE "$(docker run -ti --rm bazel/testdata:java_image_arg_echo | tr '\r' '\n')" "arg0"
}

function test_war_image() {
  cd "${ROOT}"
  clear_docker
  bazel build testdata:war_image.tar
  docker load -i bazel-bin/testdata/war_image.tar
  ID=$(docker run -d -p 8080:8080 bazel/testdata:war_image)
  sleep 5
  EXPECT_CONTAINS "$(curl localhost:8080)" "Hello World"
  docker rm -f "${ID}"
}

function test_war_image_with_custom_run_flags() {
  cd "${ROOT}"
  clear_docker
  # Use --norun to prevent actually running the war image. We are just checking
  # the `docker run` command in the generated load script contains the right
  # flags.
  bazel run testdata:war_image_with_custom_run_flags -- --norun
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/war_image_with_custom_run_flags)" "-i --rm --network=host -e ABC=ABC"
}

function test_scala_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" tests/docker/scala:scala_image)" "Hello World"
}

function test_scala_sandwich_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:scala_sandwich_image)" "Hello World"
}

function test_groovy_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" tests/docker/groovy:groovy_image)" "Hello World"
}

function test_groovy_scala_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:groovy_scala_image)" "Hello World"
}

function test_rust_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" tests/docker/rust:rust_image)" "Hello world"
}

function test_d_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:d_image)" "Hello world"
}

function test_nodejs_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run tests/docker/nodejs:nodejs_image)" "Hello World!"
}

function test_container_push() {
  cd "${ROOT}"
  clear_docker
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel build tests/docker:push_test
  # run here file_test targets to verify test outputs of push_test

  docker stop -t 0 $cid
}

# Launch a private docker registry at localhost:5000 that requires a basic
# htpasswd authentication with credentials at docker-config/htpasswd and needs
# the docker client to be using the authentication from
# docker-config/config.json.
function launch_private_registry_with_auth() {
  cd "${ROOT}"
  config_dir="${ROOT}/testing/docker-config"
  docker_run_opts=" --rm -d -p 5000:5000 --name registry"
  # Mount the registry configuration
  docker_run_opts+=" -v $config_dir/config.yml:/etc/docker/registry/config.yml"
  # Mount the HTTP password file
  docker_run_opts+=" -v $config_dir/htpasswd:/.htpasswd"
  # Lauch the local registry that requires authentication
  docker run $docker_run_opts registry:2

  # Inject the location of the docker configuration directory into the bazel
  # workspace which will be used to configure the authentication used by the
  # docker toolchain in container_push.
  config_dir="${ROOT}/testing/docker-config"
  cat > ${ROOT}/testing/custom_toolchain_auth/def.bzl <<EOF
client_config="${config_dir}"
EOF
}

# Test container push where the local registry requires htpsswd authentication
function test_container_push_with_auth() {
  clear_docker
  launch_private_registry_with_auth

  # run here file_test targets to verify test outputs of push_test

  # Run the container_push test in the Bazel workspace that configured
  # the docker toolchain rule to use authentication.
  cd "${ROOT}/testing/custom_toolchain_auth"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting authenticated container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/docker:push_test)" "localhost:5000/docker/test:test was published"
  bazel clean

  # Run the container_push test in the Bazel workspace that uses the default
  # configured docker toolchain. The default configuration doesn't setup
  # authentication and this should fail.
  cd "${ROOT}/testing/default_toolchain"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting unauthenticated container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/docker:push_test  2>&1)" "Error publishing localhost:5000/docker/test:test"
  bazel clean
}

function test_container_pull_with_auth() {
  clear_docker
  launch_private_registry_with_auth

  cd "${ROOT}/testing/custom_toolchain_auth"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  # Remove the old image if it exists
  docker rmi bazel/image:image || true
  # Push the locally built container to the private repo
  bazel run $bazel_opts @io_bazel_rules_docker//tests/docker:push_test
  echo "Attempting authenticated container pull and push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @local_pull//image)" "Loaded image"

  # Run the container_pull test in the Bazel WORKSPACE that uses the default
  # configured docker toolchain. The default configuration doesn't setup
  # authentication and this should fail.
  cd "${ROOT}/testing/default_toolchain"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting unauthenticated container_pull..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @local_pull//image 2>&1)" "Error pulling and saving image localhost:5000/docker/test:test"
}

function test_container_push_with_stamp() {
  cd "${ROOT}"
  clear_docker
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel run tests/docker:push_stamped_test
  docker stop -t 0 $cid
}

test_container_push_with_stamp
test_container_push_with_auth
test_container_pull_with_auth
test_top_level
test_bazel_build_then_run_docker_build_clean
test_bazel_run_docker_build_clean
test_bazel_run_docker_bundle_clean
test_bazel_run_docker_import_clean
test_bazel_run_docker_build_incremental
test_bazel_run_docker_bundle_incremental
test_bazel_run_docker_import_incremental
test_py_image -c opt
test_py_image -c dbg
test_py_image_complex -c opt
test_py_image_complex -c dbg
test_py3_image_with_custom_run_flags -c opt
test_py3_image_with_custom_run_flags -c dbg
test_cc_image -c opt
test_cc_image -c dbg
test_cc_binary_as_image -c opt
test_cc_binary_as_image -c dbg
test_cc_image_wrapper
test_go_image -c opt
test_go_image -c dbg
test_go_image_busybox
test_go_image_with_tags
test_java_image -c opt
test_java_image -c dbg
test_java_image_with_custom_run_flags -c opt
test_java_image_with_custom_run_flags -c dbg
test_java_sandwich_image -c opt
test_java_sandwich_image -c dbg
test_java_simple_image
test_java_image_arg_echo
test_war_image
test_war_image_with_custom_run_flags
test_scala_image -c opt
test_scala_image -c dbg
test_scala_sandwich_image -c opt
test_scala_sandwich_image -c dbg
test_groovy_image -c opt
test_groovy_image -c dbg
test_groovy_scala_image -c opt
test_groovy_scala_image -c dbg
test_rust_image -c opt
test_rust_image -c dbg
# Re-enable once https://github.com/bazelbuild/rules_d/issues/14 is fixed.
# test_d_image -c opt
# test_d_image -c dbg
test_nodejs_image -c opt
test_nodejs_image -c dbg
test_container_push
test_launcher_image
