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
CONTAINERREGISTRY_RELEASE = "v0.0.38"
RULES_DOCKER_GO_BINARY_RELEASE = "aad94363e63d31d574cf701df484b3e8b868a96a"

def repositories():
    """Download dependencies of container rules."""
    excludes = native.existing_rules().keys()

    # Go binaries.
    if "go_puller_linux_amd64" not in excludes:
        http_file(
            name = "go_puller_linux_amd64",
            executable = True,
            sha256 = "08b8963cce9234f57055bafc7cadd1624cdce3c5990048cea1df453d7d288bc6",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-linux-amd64")],
        )

    if "go_puller_linux_arm64" not in excludes:
        http_file(
            name = "go_puller_linux_arm64",
            executable = True,
            sha256 = "912ee7c469b3e4bf15ba5d1f0ee500e7ec6724518862703fa8b09e4d58ce3ee6",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-linux-arm64")],
        )

    if "go_puller_linux_s390x" not in excludes:
        http_file(
            name = "go_puller_linux_s390x",
            executable = True,
            sha256 = "a5527b7b3b4a266e4680a4ad8939429665d4173f26b35d5d317385134369e438",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-linux-s390x")],
        )

    if "go_puller_darwin" not in excludes:
        http_file(
            name = "go_puller_darwin",
            executable = True,
            sha256 = "4855c4f5927f8fb0f885510ab3e2a166d5fa7cde765fbe9aec97dc6b2761bb22",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-darwin-amd64")],
        )

    if "loader_linux_amd64" not in excludes:
        http_file(
            name = "loader_linux_amd64",
            executable = True,
            sha256 = "5e5ada66beff07f9188bdc1f99c3fa37c407fc0048cd78b9c2047e9c5516f20b",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/loader-linux-amd64")],
        )

    if "loader_linux_arm64" not in excludes:
        http_file(
            name = "loader_linux_arm64",
            executable = True,
            sha256 = "a80966d17b25dbc9313e9fc1cae74ded5916fa64dba0d33438c8adad338b44d3",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/loader-linux-arm64")],
        )

    if "loader_linux_s390x" not in excludes:
        http_file(
            name = "loader_linux_s390x",
            executable = True,
            sha256 = "0c0ebc3e0a502542547a38b51f4686a049897eeb4cbc0e2f07fc25276c57866f",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/loader-linux-s390x")],
        )

    if "loader_darwin" not in excludes:
        http_file(
            name = "loader_darwin",
            executable = True,
            sha256 = "8c9986b2b506febbff737090d9ec485cec1376c52789747573521a85194341c1",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/loader-darwin-amd64")],
        )

    if "containerregistry" not in excludes:
        http_archive(
            name = "containerregistry",
            sha256 = "a0c01fcc11db848212f8b11d89df168361f99a31eb7373ff60ce50c5d05cd74b",
            strip_prefix = "containerregistry-" + CONTAINERREGISTRY_RELEASE[1:],
            urls = [("https://github.com/google/containerregistry/archive/" +
                     CONTAINERREGISTRY_RELEASE + ".tar.gz")],
        )

    # TODO(mattmoor): Remove all of this (copied from google/containerregistry)
    # once transitive workspace instantiation lands.

    if "io_bazel_rules_go" not in excludes:
        http_archive(
            name = "io_bazel_rules_go",
            sha256 = "08c3cd71857d58af3cda759112437d9e63339ac9c6e0042add43f4d94caf632d",
            urls = [
                "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/rules_go/releases/download/v0.24.2/rules_go-v0.24.2.tar.gz",
                "https://github.com/bazelbuild/rules_go/releases/download/v0.24.2/rules_go-v0.24.2.tar.gz",
            ],
        )
    if "rules_python" not in excludes:
        http_archive(
            name = "rules_python",
            url = "https://github.com/bazelbuild/rules_python/releases/download/0.1.0/rules_python-0.1.0.tar.gz",
            sha256 = "b6d46438523a3ec0f3cead544190ee13223a52f6a6765a29eae7b7cc24cc83a0",
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
            sha256 = "1524da5fd5a0fc88c4c9257a3de05a45f135df07e6a684380dd5f659b9ce189b",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.11.0/container-structure-test-linux-amd64"],
        )

    if "structure_test_linux_aarch64" not in excludes:
        http_file(
            name = "structure_test_linux_aarch64",
            executable = True,
            sha256 = "b376ff80134d2d609c591b98d65d653a514755b4861185fd93159af7062ec65d",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.11.0/container-structure-test-linux-arm64"],
        )

    if "structure_test_darwin" not in excludes:
        http_file(
            name = "structure_test_darwin",
            executable = True,
            sha256 = "0a4ac9e221a86cda6bb9fedb2a0dfdce56f918327b8881977ad787ea15d0e82f",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.11.0/container-structure-test-darwin-amd64"],
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
            urls = [
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
            ],
            sha256 = "c6966ec828da198c5d9adbaa94c05e3a1c7f21bd012a0b29ba8ddbccb2c93b0d",
        )

    if "bazel_gazelle" not in excludes:
        http_archive(
            name = "bazel_gazelle",
            sha256 = "cdb02a887a7187ea4d5a27452311a75ed8637379a1287d8eeb952138ea485f7d",
            urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.21.1/bazel-gazelle-v0.21.1.tar.gz"],
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
