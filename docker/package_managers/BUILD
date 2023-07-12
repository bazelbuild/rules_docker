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
    "installer.sh.tpl",
    "run_download.sh.tpl",
    "run_install.sh.tpl",
])

bzl_library(
    name = "package_managers",
    deps = [
        "//container",
        "//docker/util",
        "//skylib:docker",
    ],
)

bzl_library(
    name = "apt_key",
    srcs = ["apt_key.bzl"],
    deps = [
        "//container",
        "//docker/util:run",
    ],
)

bzl_library(
    name = "download_pkgs",
    srcs = ["download_pkgs.bzl"],
    deps = [
        "//skylib:docker",
        "//skylib:path",
        "@bazel_skylib//lib:types",
    ],
)

bzl_library(
    name = "install_pkgs",
    srcs = ["install_pkgs.bzl"],
    deps = ["//skylib:docker"],
)
