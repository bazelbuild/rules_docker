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

function stop_containers() {
  docker rm -f $(docker ps -aq) > /dev/null 2>&1 || builtin true
}

# Clean up any containers [before] we start.
stop_containers
trap "stop_containers" EXIT

# Function is kept here and not used from util as they have slightly different
# behavior (this one clears all images, util only clears images with registry
# that starts with 'bazel/..')
function clear_docker_full() {
  # Get the IDs of images except the local registry image "registry:2" which is
  # used in a few of the tests. This avoids having to pull the registry image
  # multiple times in the end to end tests.
  images=$(docker images -a --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep -v "registry:2" | cut -d' ' -f1)
  docker rmi -f $images || builtin true
  stop_containers
}

function test_py_image_complex() {
  cd "${ROOT}"
  clear_docker_full
  cat > output.txt <<EOF
$(bazel run "$@" testdata:py_image_complex)
EOF
  EXPECT_CONTAINS "$(cat output.txt)" "Calling from main module: through py_image_complex_library: Six version: 1.11.0"
  EXPECT_CONTAINS "$(cat output.txt)" "Calling from main module: through py_image_complex_library: Addict version: 2.1.2"
  rm -f output.txt
}

function test_py3_image_with_custom_run_flags() {
  cd "${ROOT}"
  clear_docker_full
  cat > output.txt <<EOF
$(bazel run "$@" testdata:py3_image_with_custom_run_flags)
EOF
  EXPECT_CONTAINS "$(cat output.txt)" "First: 4"
  EXPECT_CONTAINS "$(cat output.txt)" "Second: 5"
  EXPECT_CONTAINS "$(cat output.txt)" "Third: 6"
  EXPECT_CONTAINS "$(cat output.txt)" "Fourth: 7"
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/py3_image_with_custom_run_flags.executable)" "-i --rm --network=host -e ABC=ABC"
  rm -f output.txt
}

function test_java_image() {
  cd "${ROOT}"
  clear_docker_full
  EXPECT_CONTAINS "$(bazel run "$@" testdata:java_image)" "Hello World"
}

function test_war_image() {
  cd "${ROOT}"
  clear_docker_full
  bazel build testdata:war_image.tar
  docker load -i bazel-bin/testdata/war_image.tar
  ID=$(docker run -d -p 8080:8080 bazel/testdata:war_image)
  sleep 5
  EXPECT_CONTAINS "$(curl localhost:8080)" "Hello World"
  EXPECT_CONTAINS "$(curl localhost:8080)" "WAR_IMAGE_TEST_KEY=war_image_test_value"
  docker rm -f "${ID}"
}

function test_war_image_with_custom_run_flags() {
  cd "${ROOT}"
  clear_docker_full
  # Use --norun to prevent actually running the war image. We are just checking
  # the `docker run` command in the generated load script contains the right
  # flags.
  bazel run testdata:war_image_with_custom_run_flags -- --norun
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/war_image_with_custom_run_flags.executable)" "-i --rm --network=host -e ABC=ABC"
}

function test_rust_image() {
  cd "${ROOT}"
  clear_docker_full
  EXPECT_CONTAINS "$(bazel run "$@" tests/container/rust:rust_image)" "Hello world"
}

function test_d_image() {
  cd "${ROOT}"
  clear_docker_full
  EXPECT_CONTAINS "$(bazel run "$@" testdata:d_image)" "Hello world"
}

function test_container_push() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel build tests/container:push_test
  # run here file_test targets to verify test outputs of push_test

  docker stop -t 0 $cid
}

function test_container_push_tag_file() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel build tests/container:push_tag_file_test
  EXPECT_CONTAINS "$(cat bazel-bin/tests/container/push_tag_file_test)" '--dst=localhost:5000/docker/test:$(cat ${RUNFILES}/io_bazel_rules_docker/tests/container/test.tag)'

  docker stop -t 0 $cid
}

function test_new_container_push_oci() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_oci 2>&1)" "Successfully pushed OCI image"
  docker stop -t 0 $cid
}

function test_new_container_push_skip_unchanged_digest_unchanged() {
  # test that if the digest hasnt changed and skip_unchanged_digest is True that only one tag is published
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_skip_unchanged_digest_unchanged_tag_1 2>&1)" "Successfully pushed Docker image"
  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_skip_unchanged_digest_unchanged_tag_2 2>&1)" "Skipping push of unchanged digest"
  EXPECT_CONTAINS "$(curl localhost:5000/v2/docker/test/tags/list)" '{"name":"docker/test","tags":["unchanged_tag1"]}'
}

function test_new_container_push_skip_unchanged_digest_changed() {
  # test that if the digest changes and skip_unchanged_digest is True that two tags are published
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_skip_unchanged_digest_changed_tag_1 2>&1)" "Successfully pushed Docker image"
  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_skip_unchanged_digest_changed_tag_2 2>&1)" "Successfully pushed Docker image"
  EXPECT_CONTAINS "$(curl -s localhost:5000/v2/docker/test/tags/list | jq --sort-keys -c '(.. | arrays) |= sort')" '{"name":"docker/test","tags":["changed_tag1","changed_tag2"]}'
}

function test_new_container_push_compat() {
  # OCI image pulled by new puller, target: new_push_test_oci_from_new_puller
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_oci_from_new_puller 2>&1)" "Successfully pushed OCI image"
  docker stop -t 0 $cid

  # Legacy image pulled by new puller, target: new_push_test_legacy_from_new_puller
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_legacy_from_new_puller 2>&1)" "Successfully pushed Docker image"
  docker stop -t 0 $cid

  # Legacy image pulled by old puller, target: new_push_test_legacy_from_old_puller
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_legacy_from_old_puller 2>&1)" "Successfully pushed Docker image"
  docker stop -t 0 $cid

  # Docker image tarball pulled by new puller, target: new_push_test_old_puller_tar
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_old_puller_tar 2>&1)" "Successfully pushed Docker image"
  docker stop -t 0 $cid
}

function test_new_container_push_legacy() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_legacy_from_container_img 2>&1)" "Successfully pushed Docker image"
  bazel clean

  cd "${ROOT}/testing/new_pusher_tests"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"

  EXPECT_CONTAINS "$(bazel test $bazel_opts @io_bazel_rules_docker//testing/new_pusher_tests:new_push_verify_pushed_configs_and_files 2>&1)" "Executed 1 out of 1 test: 1 test passes."
  bazel clean

  # Now pull and call the container_test target to verify the files are actually in the pushed image.
  docker stop -t 0 $cid
}

function test_new_container_push_legacy_tag_file() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel build tests/container:new_push_test_legacy_tag_file
  EXPECT_CONTAINS "$(cat bazel-bin/tests/container/new_push_test_legacy_tag_file)" '--dst=localhost:5000/docker/test:$(cat ${RUNFILES}/io_bazel_rules_docker/tests/container/test.tag)'

  docker stop -t 0 $cid
}

function test_new_container_push_legacy_with_auth() {
  clear_docker_full
  launch_private_registry_with_auth

  # Run the new_container_push test in the Bazel workspace that configured
  # the docker toolchain rule to use authentication.
  cd "${ROOT}/testing/custom_toolchain_auth"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting authenticated new container_push..."

  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/container:new_push_test_legacy_from_container_img_with_auth 2>&1)" "Successfully pushed Docker image"
  bazel clean

  # Run the new_container_push test in the Bazel workspace that uses the default
  # configured docker toolchain. The default configuration doesn't setup
  # authentication and this should fail.
  cd "${ROOT}/testing/default_toolchain"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting unauthenticated new container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/container:new_push_test_legacy_from_container_img_with_auth  2>&1)" "status code 401"
  bazel clean
}

function test_new_container_push_tar() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  EXPECT_CONTAINS "$(bazel run @io_bazel_rules_docker//tests/container:new_push_test_tar 2>&1)" "Successfully pushed Docker image"

  docker stop -t 0 $cid
}

function test_new_container_push_oci_tag_file() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel build tests/container:new_push_test_oci_tag_file
  EXPECT_CONTAINS "$(cat bazel-bin/tests/container/new_push_test_oci_tag_file)" '--dst=localhost:5000/docker/test:$(cat ${RUNFILES}/io_bazel_rules_docker/tests/container/test.tag)'

  docker stop -t 0 $cid
}

function test_new_container_push_with_stamp() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  # Push a legacy image with stamp substitution
  bazel run --stamp tests/container:new_push_stamped_test_legacy
  EXPECT_CONTAINS "$(bazel run --stamp @io_bazel_rules_docker//tests/container:new_push_stamped_test_legacy 2>&1)" "Successfully pushed Docker image"

  # Push a oci image with stamp substitution
  bazel run --stamp tests/container:new_push_stamped_test_oci
  EXPECT_CONTAINS "$(bazel run --stamp @io_bazel_rules_docker//tests/container:new_push_stamped_test_oci 2>&1)" "Successfully pushed OCI image"
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
  clear_docker_full
  launch_private_registry_with_auth

  # run here file_test targets to verify test outputs of push_test

  # Run the container_push test in the Bazel workspace that configured
  # the docker toolchain rule to use authentication.
  cd "${ROOT}/testing/custom_toolchain_auth"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting authenticated container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/container:push_test 2>&1)" "Successfully pushed Docker image to localhost:5000/docker/test:test"
  bazel clean

  # Run the container_push test in the Bazel workspace that uses the default
  # configured docker toolchain. The default configuration doesn't setup
  # authentication and this should fail.
  cd "${ROOT}/testing/default_toolchain"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting unauthenticated container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/container:push_test  2>&1)" "unable to push image to localhost:5000/docker/test:test"
  bazel clean
}

# Test container push where the local registry requires htpsswd authentication
function test_new_container_push_oci_with_auth() {
  clear_docker_full
  launch_private_registry_with_auth

  # run here file_test targets to verify test outputs of new_push_test

  # Run the new_container_push test in the Bazel workspace that configured
  # the docker toolchain rule to use authentication.
  cd "${ROOT}/testing/custom_toolchain_auth"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting authenticated new container_push..."

  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/container:new_push_test_oci 2>&1)" "Successfully pushed OCI image"
  bazel clean

  # Run the new_container_push test in the Bazel workspace that uses the default
  # configured docker toolchain. The default configuration doesn't setup
  # authentication and this should fail.
  cd "${ROOT}/testing/default_toolchain"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting unauthenticated new container_push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @io_bazel_rules_docker//tests/container:new_push_test_oci  2>&1)" "status code 401"
  bazel clean
}

function test_container_pull_with_auth() {
  clear_docker_full
  launch_private_registry_with_auth

  cd "${ROOT}/testing/custom_toolchain_auth"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  # Remove the old image if it exists
  docker rmi bazel/image:image || true
  # Push the locally built container to the private repo
  bazel run $bazel_opts @io_bazel_rules_docker//tests/container:push_test
  echo "Attempting authenticated container pull and push..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @local_pull//image)" "Loaded image"

  # Run the container_pull test in the Bazel WORKSPACE that uses the default
  # configured docker toolchain. The default configuration doesn't setup
  # authentication and this should fail.
  cd "${ROOT}/testing/default_toolchain"
  bazel_opts=" --override_repository=io_bazel_rules_docker=${ROOT}"
  echo "Attempting unauthenticated container_pull..."
  EXPECT_CONTAINS "$(bazel run $bazel_opts @local_pull//image 2>&1)" "Image pull was unsuccessful: reading image \"localhost:5000/docker/test:test\""
}

function test_container_push_with_stamp() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  bazel run --stamp tests/container:push_stamped_test
  docker stop -t 0 $cid
}

# TODO: test_new_container_push_with_stamp().
# "stamp-info-file" flag is not yet supported in new container_push, but should be tested if implemented later.

function test_container_push_all() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)
  # Use bundle push to push three images to the local registry.
  bazel run tests/container:test_docker_push_three_images_bundle
  # Pull the three images we just pushed to ensure uploaded manifests
  # are valid according to docker.
  EXPECT_CONTAINS "$(docker pull localhost:5000/image0:latest)" "Downloaded newer image"
  EXPECT_CONTAINS "$(docker pull localhost:5000/image1:latest)" "Downloaded newer image"
  EXPECT_CONTAINS "$(docker pull localhost:5000/image2:latest)" "Downloaded newer image"
  docker stop -t 0 $cid
}

function test_container_pull_cache() {
  cd "${ROOT}"
  clear_docker_full
  scratch_dir="/tmp/_tmp_containnerregistry"
  cache_dir="$scratch_dir/containnerregistry_cache"
  bazel_cache="$scratch_dir/bazel_custom_cache"

  # Delete and recreate temp directories.
  rm -rf $scratch_dir
  mkdir -p $cache_dir
  mkdir -p $bazel_cache

  # Run container puller one with caching.
  DOCKER_REPO_CACHE=$cache_dir PULLER_TIMEOUT=600 bazel --output_base=$bazel_cache test //tests/container:distroless_fixed_id_digest_test

  # Rerun the puller by changing the puller timeout to force a rerun of of the
  # target but now using the cache instead of downloading it again.
  DOCKER_REPO_CACHE=$cache_dir PULLER_TIMEOUT=601 bazel --output_base=$bazel_cache test //tests/container:distroless_fixed_id_digest_test

  rm -rf $scratch_dir
}

function test_new_container_pull_image_with_11_layers() {
  cd "${ROOT}"
  clear_docker_full
  cid=$(docker run --rm -d -p 5000:5000 --name registry registry:2)

  # Push an image with 11 layers.
  EXPECT_CONTAINS "$(bazel run //tests/container:push_image_with_11_layers 2>&1)" "Successfully pushed Docker image"

  # Pull the image with 11 layers using the Go puller and ensure it can be
  # loaded by docker which will validate the order of layers matches the order
  # indicated in the manifest. This tests the scenario reported in
  # https://github.com/bazelbuild/rules_docker/issues/1127.
  EXPECT_CONTAINS "$(bazel run @e2e_test_pull_image_with_11_layers//image 2>&1)" "Loaded image ID: sha256:"
  docker stop -t 0 $cid
}

function run_all_tests() {
    # Tests failing on GCB due to isssues with local registry
    test_container_push
    test_container_push_all
    test_container_push_tag_file
    test_container_push_with_auth
    test_container_push_with_stamp
    test_new_container_push_compat
    test_new_container_push_oci
    test_new_container_push_tar
    test_new_container_push_with_stamp
    test_new_container_push_oci_tag_file
    test_new_container_push_oci_with_auth
    test_new_container_push_legacy
    test_new_container_push_legacy_tag_file
    test_new_container_push_legacy_with_auth
    test_new_container_push_skip_unchanged_digest_unchanged
    test_new_container_push_skip_unchanged_digest_changed
    test_container_pull_with_auth
    test_container_pull_cache
    test_new_container_pull_image_with_11_layers

    # Tests failing on GCB due to permissions issue related to building tars
    test_py_image_complex -c opt
    test_py_image_complex -c dbg
    test_py3_image_with_custom_run_flags -c opt
    test_py3_image_with_custom_run_flags -c dbg
    test_java_image -c opt
    test_java_image -c dbg
    test_war_image
    test_war_image_with_custom_run_flags

    # Test failing on GCB due to clang not finding ld.gold
    test_rust_image -c opt
    test_rust_image -c dbg

    # Test failing on GCB due to not finding cc
    test_d_image -c opt
    test_d_image -c dbg
}

f="$@"
if [[ $(type -t "$f") == function ]]; then
    # run a single test if provided
    "$f"
else
    # run all tests otherwise
    run_all_tests
fi
