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
load(":toolchain.bzl", "docker_toolchain")

package(default_visibility = ["//visibility:private"])

bzl_library(
    name = "docker",
    srcs = ["toolchain.bzl"],
    visibility = ["//visibility:public"],
)

# Docker toolchain type
toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)

# Default docker toolchain that expects the 'docker' executable
# to be in the PATH.
# Also expects xz to be in PATH if needed for xz compression.
docker_toolchain(
    name = "default_toolchain_impl",
    tool_path = "docker",
    visibility = ["//visibility:public"],
    xz_path = "xz",
)

toolchain(
    name = "default_linux_toolchain",
    target_compatible_with = [
        "@platforms//os:linux",
    ],
    toolchain = "@docker_config//:toolchain",
    toolchain_type = ":toolchain_type",
)

toolchain(
    name = "default_windows_toolchain",
    target_compatible_with = [
        "@platforms//os:windows",
    ],
    toolchain = "@docker_config//:toolchain",
    toolchain_type = ":toolchain_type",
)

toolchain(
    name = "default_osx_toolchain",
    target_compatible_with = [
        "@platforms//os:osx",
    ],
    toolchain = "@docker_config//:toolchain",
    toolchain_type = ":toolchain_type",
)
