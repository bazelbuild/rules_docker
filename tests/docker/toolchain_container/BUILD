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

load("//contrib:test.bzl", "container_test")
load(
    "//docker/toolchain_container:toolchain_container.bzl",
    "language_tool_layer",
    "toolchain_container",
)

licenses(["notice"])  # Apache 2.0

package(default_visibility = ["//visibility:public"])

# This file contains some sample targets that excersise the container rules
# We just keep these as examples that should not break (unless indicated)
# with changes.

# Use "rbe-test-" prefix for easy identification of images to remove after the tests.
toolchain_container(
    name = "rbe-test-xenial-with-pkgs",
    additional_repos = [
        "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8",
    ],
    base = "@official_xenial//image",
    keys = [
        "@bazel_gpg//file",
    ],
    packages = [
        "bazel",
        "curl",
        "gcc",
        "git",
        "openjdk-8-jdk",
        "python-dev",
        "unzip",
        "wget",
        "zip",
    ],
)

language_tool_layer(
    name = "java-layer-test",
    base = "@official_xenial//image",
    packages = [
        "openjdk-8-jdk",
    ],
)

toolchain_container(
    name = "rbe-test-no-bazel",
    base = "@official_xenial//image",
    language_layers = [":java-layer-test"],
    packages = [
        "curl",
        "g++",
        "gcc",
        "git",
        "python-dev",
        "unzip",
        "wget",
        "zip",
    ],
)

container_test(
    name = "test-rbe-test-xenial-with-pkgs",
    configs = [
        ":tests.yaml",
    ],
    image = ":rbe-test-xenial-with-pkgs",
    verbose = True,
)
