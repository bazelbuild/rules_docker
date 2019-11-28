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
