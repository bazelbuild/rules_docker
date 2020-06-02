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
"""Rules to load all dependencies of rules_docker."""

load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
    "http_file",
)
load(
    "@io_bazel_rules_docker//toolchains/docker:toolchain.bzl",
    _docker_toolchain_configure = "toolchain_configure",
)

# The release of the github.com/google/containerregistry to consume.
CONTAINERREGISTRY_RELEASE = "v0.0.36"
RULES_DOCKER_GO_BINARY_RELEASE = "fdebd6e0b6c9185a115379166c1c067f88d53630"

def repositories():
    """Download dependencies of container rules."""
    excludes = native.existing_rules().keys()

    # Go binaries.
    if "go_puller_linux" not in excludes:
        http_file(
            name = "go_puller_linux",
            executable = True,
            sha256 = "1bcbbf86972cde8448dfab770a686801c46a1739f68f1d7a5373a4f0c3954846",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-linux-amd64")],
        )

    if "go_puller_darwin" not in excludes:
        http_file(
            name = "go_puller_darwin",
            executable = True,
            sha256 = "62b405511624528ba5b2716b1b93b5591c41edeca57195efc62da14001441c44",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-darwin-amd64")],
        )

    if "loader_linux" not in excludes:
        http_file(
            name = "loader_linux",
            executable = True,
            sha256 = "06b6baaddbb42854a2d854f014d3af7cd67ff40741b49ba66efd35991752efc4",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/loader-linux-amd64")],
        )

    if "loader_darwin" not in excludes:
        http_file(
            name = "loader_darwin",
            executable = True,
            sha256 = "8572f547b87143e344bcab3155b18ff438351a256b4c90dfab72beb02b46b178",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/loader-darwin-amd64")],
        )

    if "containerregistry" not in excludes:
        http_archive(
            name = "containerregistry",
            sha256 = "a8cdf2452323e0fefa4edb01c08b2ec438c9fa3192bc9f408b89287598c12abc",
            strip_prefix = "containerregistry-" + CONTAINERREGISTRY_RELEASE[1:],
            urls = [("https://github.com/google/containerregistry/archive/" +
                     CONTAINERREGISTRY_RELEASE + ".tar.gz")],
        )

    # TODO(mattmoor): Remove all of this (copied from google/containerregistry)
    # once transitive workspace instantiation lands.

    if "io_bazel_rules_go" not in excludes:
        http_archive(
            name = "io_bazel_rules_go",
            sha256 = "7b9bbe3ea1fccb46dcfa6c3f3e29ba7ec740d8733370e21cdc8937467b4a4349",
            urls = [
                "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/rules_go/releases/download/v0.22.4/rules_go-v0.22.4.tar.gz",
                "https://github.com/bazelbuild/rules_go/releases/download/v0.22.4/rules_go-v0.22.4.tar.gz",
            ],
        )
    if "rules_python" not in excludes:
        http_archive(
            name = "rules_python",
            sha256 = "0aa9ec790a58053e3ab5af397879b267a625955f8297c239b2d8559c6773397b",
            strip_prefix = "rules_python-dd7f9c5f01bafbfea08c44092b6b0c8fc8fcb77f",
            urls = ["https://github.com/bazelbuild/rules_python/archive/dd7f9c5f01bafbfea08c44092b6b0c8fc8fcb77f.tar.gz"],
        )

    # For packaging python tools.
    if "subpar" not in excludes:
        http_archive(
            name = "subpar",
            sha256 = "481233d60c547e0902d381cd4fb85b63168130379600f330821475ad234d9336",
            # Commit from 2019-03-07.
            strip_prefix = "subpar-9fae6b63cfeace2e0fb93c9c1ebdc28d3991b16f",
            urls = ["https://github.com/google/subpar/archive/9fae6b63cfeace2e0fb93c9c1ebdc28d3991b16f.tar.gz"],
        )

    if "structure_test_linux" not in excludes:
        http_file(
            name = "structure_test_linux",
            executable = True,
            sha256 = "cfdfedd77c04becff0ea16a4b8ebc3b57bf404c56e5408b30d4fbb35853db67c",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.8.0/container-structure-test-linux-amd64"],
        )

    if "structure_test_darwin" not in excludes:
        http_file(
            name = "structure_test_darwin",
            executable = True,
            sha256 = "14e94f75112a8e1b08a2d10f2467d27db0b94232a276ddd1e1512593a7b7cf5a",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.8.0/container-structure-test-darwin-amd64"],
        )

    if "container_diff" not in excludes:
        http_file(
            name = "container_diff",
            executable = True,
            sha256 = "65b10a92ca1eb575037c012c6ab24ae6fe4a913ed86b38048781b17d7cf8021b",
            urls = ["https://storage.googleapis.com/container-diff/v0.15.0/container-diff-linux-amd64"],
        )

    # For bzl_library.
    if "bazel_skylib" not in excludes:
        http_archive(
            name = "bazel_skylib",
            sha256 = "e5d90f0ec952883d56747b7604e2a15ee36e288bb556c3d0ed33e818a4d971f2",
            strip_prefix = "bazel-skylib-1.0.2",
            urls = ["https://github.com/bazelbuild/bazel-skylib/archive/1.0.2.tar.gz"],
        )

    if "bazel_gazelle" not in excludes:
        http_archive(
            name = "bazel_gazelle",
            sha256 = "bfd86b3cbe855d6c16c6fce60d76bd51f5c8dbc9cfcaef7a2bb5c1aafd0710e8",
            urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.21.0/bazel-gazelle-v0.21.0.tar.gz"],
        )

    if "rules_pkg" not in excludes:
        http_archive(
            name = "rules_pkg",
            sha256 = "aeca78988341a2ee1ba097641056d168320ecc51372ef7ff8e64b139516a4937",
            urls = ["https://github.com/bazelbuild/rules_pkg/releases/download/0.2.6-1/rules_pkg-0.2.6.tar.gz"],
        )

    native.register_toolchains(
        # Register the default docker toolchain that expects the 'docker'
        # executable to be in the PATH
        "@io_bazel_rules_docker//toolchains/docker:default_linux_toolchain",
        "@io_bazel_rules_docker//toolchains/docker:default_windows_toolchain",
        "@io_bazel_rules_docker//toolchains/docker:default_osx_toolchain",
    )

    if "docker_config" not in excludes:
        # Automatically configure the docker toolchain rule to use the default
        # docker binary from the system path
        _docker_toolchain_configure(name = "docker_config")
