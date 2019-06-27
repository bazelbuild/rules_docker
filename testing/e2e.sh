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
source ./testing/e2e/util.sh

# Must be invoked from the root of the repo.
ROOT=$PWD
CONTAINER_IMAGE_TARGETS_QUERY="
bazel query 'kind(\"container_image\", \"testdata/...\") except
    (\"//testdata:py3_image_base_with_custom_run_flags\" union
    \"//testdata:java_image_base_with_custom_run_flags\" union
    \"//testdata:docker_run_flags_use_default\" union
    \"//testdata:docker_run_flags_overrides_default\" union
    \"//testdata:docker_run_flags_inherits_base\" union
    \"//testdata:docker_run_flags_overrides_base\" union
    \"//testdata:war_image_base_with_custom_run_flags\")'
"

# Clean up any containers [before] we start.
stop_containers
trap "stop_containers" EXIT

function clear_docker() {
  # Get the IDs of images except the local registry image "registry:2" which is
  # used in a few of the tests. This avoids having to pull the registry image
  # multiple times in the end to end tests.
  images=$(docker images -a --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep -v "registry:2" | cut -d' ' -f1)
  docker rmi -f $images || builtin true
  stop_containers
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

function test_launcher_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:launcher_image)" "Launched via launcher!"
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

function test_container_push() {
  cd "${ROOT}"
  clear_docker
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel build tests/docker:push_test
  # run here file_test targets to verify test outputs of push_test

  docker stop -t 0 $cid
}

function test_container_push_tag_file() {
  cd "${ROOT}"
  clear_docker
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel build tests/docker:push_tag_file_test
  EXPECT_CONTAINS "$(cat bazel-bin/tests/docker/push_tag_file_test)" '--name=localhost:5000/docker/test:$(cat ${RUNFILES}/io_bazel_rules_docker/tests/docker/test.tag)'

  docker stop -t 0 $cid
}

function test_new_container_push_oci() {
  cd "${ROOT}"
  clear_docker
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/docker:new_push_test_oci 2>&1)" "Successfully pushed oci image"
  docker stop -t 0 $cid
}

function test_new_container_push_tar() {
  cd "${ROOT}"
  clear_docker
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/docker:new_push_test_tar 2>&1)" "Successfully pushed docker image"

  docker stop -t 0 $cid
}
function test_new_container_push_tag_file() {
  cd "${ROOT}"
  clear_docker
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel build tests/docker:new_push_tag_file_test
  EXPECT_CONTAINS "$(cat bazel-bin/tests/docker/new_push_tag_file_test)" '-dst localhost:5000/docker/test:$(cat ${RUNFILES}/io_bazel_rules_docker/tests/docker/test.tag)'

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
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT} --host_force_python=PY2"
  echo "Attempting authenticated container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/docker:push_test)" "localhost:5000/docker/test:test was published"
  bazel clean

  # Run the container_push test in the Bazel workspace that uses the default
  # configured docker toolchain. The default configuration doesn't setup
  # authentication and this should fail.
  cd "${ROOT}/testing/default_toolchain"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT} --host_force_python=PY2"
  echo "Attempting unauthenticated container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/docker:push_test  2>&1)" "Error publishing localhost:5000/docker/test:test"
  bazel clean
}

# Test container push where the local registry requires htpsswd authentication
function test_new_container_push_with_auth() {
  clear_docker
  launch_private_registry_with_auth

  # run here file_test targets to verify test outputs of new_push_test

  # Run the new_container_push test in the Bazel workspace that configured
  # the docker toolchain rule to use authentication.
  cd "${ROOT}/testing/custom_toolchain_auth"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting authenticated new container_push..."

  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/docker:new_push_test_oci 2>&1)" "Successfully pushed oci image from"
  bazel clean

  # Run the new_container_push test in the Bazel workspace that uses the default
  # configured docker toolchain. The default configuration doesn't setup
  # authentication and this should fail.
  cd "${ROOT}/testing/default_toolchain"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting unauthenticated new container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/docker:new_push_test_oci  2>&1)" "unable to push image to localhost:5000/docker/test:test: unsupported status code 401"
  bazel clean
}


function test_container_pull_with_auth() {
  clear_docker
  launch_private_registry_with_auth

  cd "${ROOT}/testing/custom_toolchain_auth"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT} --host_force_python=PY2"
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
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT} --host_force_python=PY2"
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

# TODO: test_new_container_push_with_stamp().
# "stamp-info-file" flag is not yet supported in new container_push, but should be tested if implemented later.

function test_container_push_all() {
  cd "${ROOT}"
  clear_docker
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  # Use bundle push to push three images to the local registry.
  bazel run tests/docker:test_docker_push_three_images_bundle
  # Pull the three images we just pushed to ensure uploaded manifests
  # are valid according to docker.
  EXPECT_CONTAINS "$(docker pull localhost:5000/image0:latest)" "Downloaded newer image"
  EXPECT_CONTAINS "$(docker pull localhost:5000/image1:latest)" "Downloaded newer image"
  EXPECT_CONTAINS "$(docker pull localhost:5000/image2:latest)" "Downloaded newer image"
  docker stop -t 0 $cid
}

function test_container_pull_cache() {
  cd "${ROOT}"
  clear_docker
  scratch_dir="/tmp/_tmp_containnerregistry"
  cache_dir="$scratch_dir/containnerregistry_cache"
  bazel_cache="$scratch_dir/bazel_custom_cache"

  # Delete and recreate temp directories.
  rm -rf $scratch_dir
  mkdir -p $cache_dir
  mkdir -p $bazel_cache

  # Run container puller one with caching.
  DOCKER_REPO_CACHE=$cache_dir PULLER_TIMEOUT=600 bazel --output_base=$bazel_cache test //tests/docker:distoless_fixed_id_digest_test

  # Rerun the puller by changing the puller timeout to force a rerun of of the
  # target but now using the cache instead of downloading it again.
  DOCKER_REPO_CACHE=$cache_dir PULLER_TIMEOUT=601 bazel --output_base=$bazel_cache test //tests/docker:distoless_fixed_id_digest_test

  rm -rf $scratch_dir
}

function test_py_image_deps_as_layers() {
  cd "${ROOT}"
  clear_docker
  # Build and run the python image where the "six" module pip dependency was
  # specified via "layers". https://github.com/bazelbuild/rules_docker/issues/161
  EXPECT_CONTAINS "$(bazel run testdata/test:py_image_using_layers)" "Successfully imported six 1.11.0"
}

test_py_image_deps_as_layers
test_container_push_with_stamp
test_container_push_all
test_container_push_with_auth
test_new_container_push_oci
test_new_container_push_tar
test_new_container_push_tag_file
test_new_container_push_with_auth
test_container_pull_with_auth
test_py_image -c opt
test_py_image -c dbg
test_py_image_complex -c opt
test_py_image_complex -c dbg
test_py3_image_with_custom_run_flags -c opt
test_py3_image_with_custom_run_flags -c dbg
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
test_container_push
test_container_push_tag_file
test_launcher_image
test_container_pull_cache
