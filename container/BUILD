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

exports_files([
    "push-tag.bat.tpl",
    "push-tag.sh.tpl",
])

filegroup(
    name = "incremental_load_template",
    srcs = ["incremental_load.sh.tpl"],
    visibility = ["//visibility:public"],
)

# TODO(xingao): Flip legacy_create_init to False if possible.
py_binary(
    name = "build_tar",
    srcs = ["build_tar.py"],
    legacy_create_init = True,
    python_version = "PY3",
    srcs_version = "PY2AND3",
    visibility = ["//visibility:public"],
    deps = [":build_tar_lib"],
)

py_library(
    name = "build_tar_lib",
    srcs = [
        "archive.py",
        "build_tar.py",
    ],
    srcs_version = "PY2AND3",
    visibility = ["//visibility:public"],
)

bzl_library(
    name = "bundle",
    srcs = ["bundle.bzl"],
    deps = [
        ":layer_tools",
        ":providers",
        "//skylib:label",
        "@bazel_skylib//lib:dicts",
    ],
)

bzl_library(
    name = "container",
    srcs = ["container.bzl"],
    deps = [
        ":bundle",
        ":flatten",
        ":image",
        ":import",
        ":layer",
        ":load",
        ":push",
    ],
)

bzl_library(
    name = "container.docs",
    srcs = ["container.docs.bzl"],
    deps = ["container"],
)

bzl_library(
    name = "flatten",
    srcs = ["flatten.bzl"],
    deps = [
        ":layer_tools",
        ":providers",
        "//skylib:label",
    ],
)

bzl_library(
    name = "image",
    srcs = ["image.bzl"],
    deps = [
        ":layer",
        ":layer_tools",
        ":providers",
        "//skylib:filetype",
        "//skylib:hash",
        "//skylib:label",
        "//skylib:path",
        "@bazel_skylib//lib:dicts",
    ],
)

bzl_library(
    name = "import",
    srcs = ["import.bzl"],
    deps = [
        ":layer_tools",
        ":providers",
        "//skylib:filetype",
        "//skylib:hash",
        "//skylib:path",
        "//skylib:zip",
    ],
)

bzl_library(
    name = "layer",
    srcs = ["layer.bzl"],
    deps = [
        ":layer_tools",
        ":providers",
        "//skylib:filetype",
        "//skylib:hash",
        "//skylib:path",
        "//skylib:zip",
    ],
)

bzl_library(
    name = "layer_tools",
    srcs = ["layer_tools.bzl"],
    deps = [
        "//skylib:docker",
        "//skylib:path",
    ],
)

bzl_library(
    name = "load",
    srcs = ["load.bzl"],
    deps = [":pull"],
)

bzl_library(
    name = "providers",
    srcs = ["providers.bzl"],
)

bzl_library(
    name = "pull",
    srcs = ["pull.bzl"],
)

bzl_library(
    name = "push",
    srcs = ["push.bzl"],
    deps = [
        ":layer_tools",
        ":providers",
        "//skylib:path",
    ],
)
