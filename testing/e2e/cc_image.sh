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

# Tests for cc_image

# Must be invoked from the root of the repo.
ROOT=$PWD

function test_cc_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" tests/container/cc:cc_image)" "Hello World"
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

