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

load("@bazel_toolchains//rules/experimental/rbe:exec_properties.bzl", "merge_dicts")
load("@exec_properties//:constants.bzl", "DOCKER_SIBLINGS_CONTAINERS", "NETWORK_ON")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

toolchain(
    name = "rbe_cc_toolchain",
    exec_compatible_with = [
        "@io_bazel_rules_docker//toolchains:run_in_container",
        "@bazel_tools//platforms:x86_64",
        "@bazel_tools//platforms:linux",
        "@bazel_tools//tools/cpp:clang",
    ],
    target_compatible_with = [
        "@bazel_tools//platforms:linux",
        "@bazel_tools//platforms:x86_64",
    ],
    toolchain = "@buildkite_config//cc:cc-compiler-k8",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

# Default host platform that has constraint_value set for the
# "@io_bazel_rules_docker//toolchains:run_in_container" constraint
platform(
    name = "local_container_platform",
    constraint_values = [
        "@io_bazel_rules_docker//toolchains:run_in_container",
    ],
    cpu_constraints = [
        "@platforms//cpu:x86_32",
        "@platforms//cpu:x86_64",
        "@platforms//cpu:ppc",
        "@platforms//cpu:arm",
        "@platforms//cpu:aarch64",
        "@platforms//cpu:s390x",
    ],
    host_platform = True,
    os_constraints = [
        "@platforms//os:osx",
        "@platforms//os:freebsd",
        "@platforms//os:linux",
        "@platforms//os:windows",
    ],
)

platform(
    name = "rbe_container_platform",
    constraint_values = [
        "@io_bazel_rules_docker//toolchains:run_in_container",
    ],
    exec_properties = merge_dicts(DOCKER_SIBLINGS_CONTAINERS, NETWORK_ON),
    parents = ["@buildkite_config//config:platform"],
)

platform(
    name = "rbe_platform",
    exec_properties = merge_dicts(DOCKER_SIBLINGS_CONTAINERS, NETWORK_ON),
    parents = ["@buildkite_config//config:platform"],
)

# Constraints used to describe docker compatible toolchains.

constraint_setting(name = "docker")

constraint_value(
    name = "run_in_container",
    constraint_setting = ":docker",
)
