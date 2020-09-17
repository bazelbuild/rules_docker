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

# Tests that a minimal repo with a docker_build rule can be built

# Must be invoked from the root of the repo.
ROOT=$PWD

function test_top_level() {
    local directory=$(mktemp -d)

  cd "${directory}"

  cat > "BUILD" <<EOF
package(default_visibility = ["//visibility:private"])
load(
  "@io_bazel_rules_docker//docker:docker.bzl",
  "docker_build",
)
docker_build(
  name = "pause_based",
  base = "@pause//image",
  workdir = "/tmp",
)
EOF

  cat > "WORKSPACE" <<EOF
workspace(name = "top_level")
local_repository(
    name = "io_bazel_rules_docker",
    path = "$ROOT",
)
load(
  "@io_bazel_rules_docker//repositories:repositories.bzl",
  container_repositories = "repositories",
)
container_repositories()

load(
    "@io_bazel_rules_docker//repositories:go_repositories.bzl",
    container_go_deps = "go_deps",
)

container_go_deps()

load(
  "@io_bazel_rules_docker//docker:docker.bzl",
  "docker_pull",
)
docker_pull(
  name = "pause",
  registry = "gcr.io",
  repository = "google-containers/pause",
  tag = "3.1",
)
EOF

  bazel build --verbose_failures --spawn_strategy=standalone --toolchain_resolution_debug :pause_based
}

# Call function above
test_top_level
