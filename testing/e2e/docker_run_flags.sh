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

# Tests for use of docker run flags

# Must be invoked from the root of the repo.
ROOT=$PWD

function test_docker_run_flags_use_default() {
  cd "${ROOT}"
  clear_docker
  bazel build testdata:docker_run_flags_use_default
  # This depends on the generated image name to ensure no _additional_ flags other than the default were included
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/docker_run_flags_use_default)" "-i --rm --network=host bazel/testdata:docker_run_flags_use_default"
}

function test_docker_run_flags_override_default() {
  cd "${ROOT}"
  clear_docker
  bazel build testdata:docker_run_flags_overrides_default
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/docker_run_flags_overrides_default)" "-i --rm --network=host -e ABC=ABC"
}

function test_docker_run_flags_inherit_from_base() {
  cd "${ROOT}"
  clear_docker
  bazel build testdata:docker_run_flags_inherits_base
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/docker_run_flags_inherits_base)" "-i --rm --network=host -e ABC=ABC"
}

function test_docker_run_flags_overrides_base() {
  cd "${ROOT}"
  clear_docker
  bazel build testdata:docker_run_flags_overrides_base
  EXPECT_CONTAINS "$(cat bazel-bin/testdata/docker_run_flags_overrides_base)" "-i --rm --network=host -e ABC=DEF"
}

# Call functions above. 1st parameter must be a function defined above
# (simple approach to make migration easy for e2e.sh)
$1
