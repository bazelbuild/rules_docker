# Copyright 2017 The Bazel Authors. All rights reserved.
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

load("@bazel_gazelle//:def.bzl", "gazelle")
load("//contrib:test.bzl", "container_test")
load("@rules_pkg//:pkg.bzl", "pkg_tar")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

exports_files(["LICENSE"])

exports_files(["WORKSPACE"])

gazelle(
    name = "gazelle",
    prefix = "github.com/bazelbuild/rules_docker",
)
# Make Gazelle ignore Go files in the tesdata directory used by test Go Image
# targets.
# gazelle:exclude testdata

config_setting(
    name = "fastbuild",
    values = {"compilation_mode": "fastbuild"},
)

config_setting(
    name = "debug",
    values = {"compilation_mode": "dbg"},
)

config_setting(
    name = "optimized",
    values = {"compilation_mode": "opt"},
)

# This is used to test the case where the test target is located at the root of
# the workspace, which makes the Bazel package empty.
container_test(
    name = "structure_test_at_workspace_root",
    configs = ["//tests/container/configs:test.yaml"],
    image = "//testdata:link_with_files_base",
)

write_file(
    name = "empty_BUILD",
    # Named with .bazel extension to not collide with this file
    out = "BUILD.bazel",
    content = [],
)

pkg_tar(
    name = "rules_docker",
    srcs = [
        "BUILD.bazel",
        "LICENSE",
        "//container:distro",
        "//contrib:distro",
        "//skylib:distro",
        "//toolchains/docker:distro",
    ],
    extension = "tar.gz",
    mode = "0444",
    # Make it owned by root so it does not have the uid of the CI robot.
    owner = "0.0",
    package_dir = ".",
    strip_prefix = ".",
    visibility = ["//examples:__pkg__"],
)
