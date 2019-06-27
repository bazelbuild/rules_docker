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

BAZEL_FLAGS="--action_env=PATH --verbose_failures"

function test_nodejs_image() {
  cd "${ROOT}"
  EXPECT_CONTAINS "$(bazel run tests/docker/nodejs:nodejs_image)" "Hello World!"
}

# Call function above with 3 parameters
# (simple approach to make migration easy for e2e.sh)
$1 $2 $3
