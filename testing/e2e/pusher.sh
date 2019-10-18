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

# Tests for the container pusher.

# Must be invoked from the root of the repo.
ROOT=$PWD

function test_pusher_client_config_errors() {
  # Ensure the pusher validates a given client config path is a valid directory.
  cd "${ROOT}"
  common_opts="--dst=foo:latest --format=Docker --config=foo.json"
  # Test for non-existent paths.
  EXPECT_CONTAINS "$(bazel run //container/go/cmd/pusher -- --client-config-dir=baddir ${common_opts} 2>&1)" "unable to stat"
  # Test for a valid path that is not a directory.
  EXPECT_CONTAINS "$(bazel run //container/go/cmd/pusher -- --client-config-dir=${ROOT}/WORKSPACE ${common_opts} 2>&1)" "is not a directory"
  echo "test_pusher_client_config_errors PASSED!"
}

test_pusher_client_config_errors
