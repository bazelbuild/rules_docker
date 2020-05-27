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

# Tests for the container puller.

# Must be invoked from the root of the repo.
ROOT=$PWD

function test_puller_timeout() {
  # Ensure the puller respects the PULLER_TIMEOUT environment variable. Try
  # pulling a large image but set a very low timeout of 1s which should fail if
  # the puller is respecting timeouts.
  # NOTE: Potential race condition between the Bazel timeout mechanism and the go puller's.
  #       Could result in test flakes.
  #       See: https://github.com/bazelbuild/rules_docker/pull/1495#issuecomment-627969114
  cd "${ROOT}"
  EXPECT_CONTAINS "$(PULLER_TIMEOUT=1 bazel build @large_image_timeout_test//image 2>&1)" "ERROR: Pull command failed: Timed out"
  echo "test_puller_timeout PASSED!"
}

test_puller_timeout
