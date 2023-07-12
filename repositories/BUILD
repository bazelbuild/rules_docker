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

bzl_library(
    name = "deps",
    srcs = ["deps.bzl"],
    deps = [
        ":go_repositories",
        "@rules_pkg//:deps",
    ],
)

bzl_library(
    name = "go_repositories",
    srcs = ["go_repositories.bzl"],
    deps = [
        "@bazel_gazelle//:deps",
        "@io_bazel_rules_go//go:deps",
    ],
)

bzl_library(
    name = "images",
    srcs = ["images.bzl"],
    deps = ["//container"],
)

bzl_library(
    name = "py_repositories",
    srcs = ["py_repositories.bzl"],
    deps = ["@rules_python//python:pip"],
)

bzl_library(
    name = "repositories",
    srcs = ["repositories.bzl"],
    deps = [
        "@bazel_tools//tools/build_defs/repo:http.bzl",
        "@io_bazel_rules_docker//toolchains/docker:toolchain",
    ],
)
