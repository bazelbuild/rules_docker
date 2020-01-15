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

# Tests for java_image

# Must be invoked from the root of the repo.
ROOT=$PWD

function test_java_partial_entrypoint_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:java_partial_entrypoint_image examples.images.Binary)" "Hello World"
}

function test_java_image_with_custom_run_flags() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:java_image_with_custom_run_flags)" "Hello World"
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/java_image_with_custom_run_flags.executable)" "-i --rm --network=host -e ABC=ABC"
}

function test_java_sandwich_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" testdata:java_sandwich_image)" "Hello World"
}

function test_java_simple_image() {
  cd "${ROOT}"
  clear_docker
  bazel run tests/container/java:simple_java_image
  docker run -d --rm bazel/tests/container/java:simple_java_image
}

function test_java_image_arg_echo() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS_ONCE "$(bazel run "$@" testdata:java_image_arg_echo)" "arg0"
  id=$(docker run -d bazel/testdata:java_image_arg_echo | tr '\r' '\n')
  docker wait $id
  logs=$(docker logs $id)
  EXPECT_CONTAINS_ONCE $logs "arg0"
}

# Call functions above with either 3 or 1 parameter
# If 3 parameters: 1st parameter is name of function, 2nd and 3rd
# passed as args
# If 1 parameter: parameter is name of function
# (simple approach to make migration easy for e2e.sh)
if [[ $# -ne 1 ]]; then
  $1 $2 $3
else
  $1
fi

