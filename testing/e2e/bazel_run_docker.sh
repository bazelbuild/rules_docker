#!/usr/bin/env bash
set -ex
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

# Tests that run several build + run combinations of multiple images

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

function test_bazel_run_docker_build_clean() {
  cd "${ROOT}"
  clear_docker
  for target in $(eval $CONTAINER_IMAGE_TARGETS_QUERY);
  do
    bazel run $target
  done
}

function test_bazel_run_docker_bundle_clean() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_bundle", "testdata/...")');
  do
    bazel run $target
  done
}

function test_bazel_run_docker_import_clean() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_import", "testdata/...")');
  do
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

function test_bazel_build_then_run_docker_build_clean() {
  cd "${ROOT}"
  clear_docker
  for target in $(eval $CONTAINER_IMAGE_TARGETS_QUERY);
  do
    bazel build $target
    # Replace : with /
    ./bazel-bin/${target/://}
  done
}

# Call functions above. 1st parameter must be a function defined above
# (simple approach to make migration easy for e2e.sh)
$1
