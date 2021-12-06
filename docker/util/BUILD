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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

py_binary(
    name = "config_stripper",
    srcs = ["config_stripper.py"],
    python_version = "PY3",
)

py_binary(
    name = "to_json",
    srcs = ["to_json.py"],
    python_version = "PY3",
)

exports_files([
    "commit.sh.tpl",
    "extract.sh.tpl",
    "image_util.sh.tpl",
    "commit_layer.sh.tpl",
])

bzl_library(
    name = "util",
    srcs = ["run.bzl"],
    deps = ["//skylib:docker"],
)

# Re-package config_stripper as a library to be used in unit tests.
py_library(
    name = "config_stripper_lib",
    srcs = [
        "config_stripper.py",
    ],
)

py_test(
    name = "config_stripper_test",
    size = "medium",
    srcs = ["config_stripper_test.py"],
    data = ["//docker/util/testdata:image_with_symlinked_layer.tar"],
    python_version = "PY3",
    deps = [":config_stripper_lib"],
)
