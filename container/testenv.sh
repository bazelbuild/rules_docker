#!/usr/bin/env bash

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

# Integration test for docker, test environment.

[ -z "$TEST_SRCDIR" ] && { echo "TEST_SRCDIR not set!" >&2; exit 1; }

# Load the unit-testing framework
# source "${TEST_SRCDIR}/io_bazel/src/test/shell/unittest.bash" || \
#   { echo "Failed to source unittest.bash" >&2; exit 1; }

function fail() {
  echo "FAILURE: $1"
  exit 1
}

# Die if "$1" != "$2", print $3 as death reason
check_eq () {
    echo Checking "$1" = "$2"
    [ "$1" = "$2" ] || fail "Check failed: '$1' == '$2' ${3:+ ($3)}"
}

readonly TEST_DATA_DIR="${TEST_SRCDIR}/io_bazel_rules_docker/testdata"

readonly TEST_DATA_TARGET_BASE="testdata"
