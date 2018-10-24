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
package(default_visibility = ["//visibility:private"])

load(":docker_toolchain.bzl", "docker_toolchain")

py_binary(
    name = "update_deps",
    srcs = ["update_deps.py"],
    deps = [
        "@containerregistry",
    ],
)

# Docker toolchain type
toolchain_type(
    name = "toolchain_type_docker",
)

# Default docker toolchain that expects the 'docker' executable
# to be in the PATH
docker_toolchain(
    name = "docker_default_toolchain_impl",
    tool_path = "docker",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "docker_default_linux_toolchain",
    exec_compatible_with = [
        "@bazel_tools//platforms:linux",
        "@bazel_tools//platforms:x86_64",
    ],
    target_compatible_with = [
        "@bazel_tools//platforms:linux",
        "@bazel_tools//platforms:x86_64",
    ],
    toolchain = ":docker_default_toolchain_impl",
    toolchain_type = ":toolchain_type_docker",
)

toolchain(
    name = "docker_default_windows_toolchain",
    exec_compatible_with = [
        "@bazel_tools//platforms:windows",
        "@bazel_tools//platforms:x86_64",
    ],
    target_compatible_with = [
        "@bazel_tools//platforms:windows",
        "@bazel_tools//platforms:x86_64",
    ],
    toolchain = ":docker_default_toolchain_impl",
    toolchain_type = ":toolchain_type_docker",
)

toolchain(
    name = "docker_default_osx_toolchain",
    exec_compatible_with = [
        "@bazel_tools//platforms:osx",
        "@bazel_tools//platforms:x86_64",
    ],
    target_compatible_with = [
        "@bazel_tools//platforms:osx",
        "@bazel_tools//platforms:x86_64",
    ],
    toolchain = ":docker_default_toolchain_impl",
    toolchain_type = ":toolchain_type_docker",
)
