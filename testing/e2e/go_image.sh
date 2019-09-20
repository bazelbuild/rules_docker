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

# Tests for go_image

# Must be invoked from the root of the repo.
ROOT=$PWD

function test_go_image() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel run "$@" tests/container/go:go_image)" "Hello, world!"
}

function test_go_image_busybox() {
  cd "${ROOT}"
  clear_docker
  bazel run -c dbg tests/container/go:go_image -- --norun
  local number=$RANDOM
  id=$(docker run -d  --entrypoint=sh bazel/tests/container/go:go_image -c "echo aa${number}bb")
  docker wait $id
  logs=$(docker logs $id)
  EXPECT_CONTAINS $logs "aa${number}bb"
}

function test_go_image_with_tags() {
  cd "${ROOT}"
  clear_docker
  EXPECT_CONTAINS "$(bazel query //tests/container/go:go_image)" "//tests/container/go:go_image"
  EXPECT_CONTAINS "$(bazel query 'attr(tags, tag1, //tests/container/go:go_image)')" "//tests/container/go:go_image"
  EXPECT_CONTAINS "$(bazel query 'attr(tags, tag2, //tests/container/go:go_image)')" "//tests/container/go:go_image"
  EXPECT_NOT_CONTAINS "$(bazel query 'attr(tags, other_tag, //tests/container/go:go_image)')" "//tests/container/go:go_image"
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

