#!/bin/bash -ex

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
  "@io_bazel_rules_docker//docker:docker.bzl",
  "docker_repositories", "docker_pull"
)
docker_repositories()

docker_pull(
  name = "pause",
  registry = "gcr.io",
  repository = "google-containers/pause",
  tag = "2.0",
)
EOF

  bazel build --verbose_failures --spawn_strategy=standalone :pause_based
}

# We test this out-of-line because of the nonsense requiring go_prefix
# to be defined in //:go_prefix.  This means we can't test Go in a repo
# defining repository rules without requiring all downstream consumers
# to import Go unnecessarily.
function test_go_image() {
  local directory=$(mktemp -d)

  cd "${directory}"

  cat > "WORKSPACE" <<EOF
workspace(name = "go_image")

local_repository(
    name = "io_bazel_rules_docker",
    path = "$ROOT",
)
load(
  "@io_bazel_rules_docker//docker:docker.bzl",
  "docker_repositories",
)
docker_repositories()

# We must load these before the go_image rule.
git_repository(
    name = "io_bazel_rules_go",
    remote = "https://github.com/bazelbuild/rules_go.git",
    tag = "0.4.4",
)
load("@io_bazel_rules_go//go:def.bzl", "go_repositories")
go_repositories()

load(
  "@io_bazel_rules_docker//docker/contrib/go:image.bzl",
  "repositories",
)
repositories()
EOF

  cat > "BUILD" <<EOF
package(default_visibility = ["//visibility:public"])

# Go boilerplate
load("@io_bazel_rules_go//go:def.bzl", "go_prefix")
go_prefix("github.com/bazelbuild/rules_docker/testing/go_image")

load(
  "@io_bazel_rules_docker//docker/contrib/go:image.bzl",
  "go_image"
)

go_image(
  name = "go_image",
  srcs = ["main.go"],
)
EOF

  cat > "main.go" <<EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello, world!")
}
EOF

  bazel run --verbose_failures --spawn_strategy=standalone :go_image
  docker run -ti --rm bazel:go_image
}


function clear_docker() {
  docker rmi -f $(docker images -aq) || true
}

function test_bazel_run_docker_build_clean() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_build", "docker/testdata/...")');
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_bundle_clean() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_bundle", "docker/testdata/...")');
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_import_clean() {
  cd "${ROOT}"
  for target in $(bazel query 'kind("docker_import", "docker/testdata/...")');
  do
    clear_docker
    bazel run $target
  done
}

function test_bazel_run_docker_build_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_build", "docker/testdata/...")');
  do
    bazel run $target
  done
}

function test_bazel_run_docker_bundle_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_bundle", "docker/testdata/...")');
  do
    bazel run $target
  done
}

function test_bazel_run_docker_import_incremental() {
  cd "${ROOT}"
  clear_docker
  for target in $(bazel query 'kind("docker_import", "docker/testdata/...")');
  do
    bazel run $target
  done
}

function test_py_image() {
  cd "${ROOT}"
  clear_docker
  bazel run docker/testdata:py_image
  docker run -ti --rm bazel/docker/testdata:py_image
}

function test_cc_image() {
  cd "${ROOT}"
  clear_docker
  bazel run docker/testdata:cc_image
  docker run -ti --rm bazel/docker/testdata:cc_image
}

test_top_level
test_go_image
test_bazel_run_docker_build_clean
test_bazel_run_docker_bundle_clean
test_bazel_run_docker_import_clean
test_bazel_run_docker_build_incremental
test_bazel_run_docker_bundle_incremental
test_bazel_run_docker_import_incremental
test_py_image
test_cc_image
