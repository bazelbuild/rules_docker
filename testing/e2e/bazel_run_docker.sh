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

# Must be invoked from the root of the repo.
ROOT=$PWD

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
  for target in $(eval $CONTAINER_IMAGE_TARGETS_QUERY);
  do
    bazel run $target
  done
}

function test_bazel_run_docker_bundle_incremental() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_bundle", "testdata/...")');
  do
    bazel run $target
  done
}

function test_bazel_run_docker_import_incremental() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_import", "testdata/...")');
  do
    bazel run $target
  done
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

# Call functions above with 1st parameter
# (simple approach to make migration easy for e2e.sh)
$1
