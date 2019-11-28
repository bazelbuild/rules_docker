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
RULES_DOCKER_GO_BINARY_RELEASE = "db8af45b844ed6ee5150984986b3f1ba9292e3a1"

def repositories():
    """Download dependencies of container rules."""
    excludes = native.existing_rules().keys()

    # Go binaries.
    if "go_puller_linux" not in excludes:
        http_file(
            name = "go_puller_linux",
            executable = True,
            sha256 = "6e7265ac5353fe802aea5070e80a2ade13404325bae4aca33387d833c9f7ac8a",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-linux-amd64")],
        )

    if "go_puller_darwin" not in excludes:
        http_file(
            name = "go_puller_darwin",
            executable = True,
            sha256 = "342c0d9f320fd383aafc6a102c752d7f2736ef6ce535e29e4779df69dc70c659",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-darwin-amd64")],
        )

    if "loader_linux" not in excludes:
        http_file(
            name = "loader_linux",
            executable = True,
            sha256 = "963bcf309a2750f59576d02cb5cf158b77c5b160b22bdff2853eab5fb03e7197",
            urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/loader-linux-amd64")],
        )

    if "loader_darwin" not in excludes:
        http_file(
            name = "loader_darwin",
            executable = True,
            sha256 = "e88232c335961bccd0efba967307a1f4307ce1c0edffbf5782590a7b012d48bd",
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
            sha256 = "b9aa86ec08a292b97ec4591cf578e020b35f98e12173bbd4a921f84f583aebd9",
            urls = [
                "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/rules_go/releases/download/v0.20.2/rules_go-v0.20.2.tar.gz",
                "https://github.com/bazelbuild/rules_go/releases/download/v0.20.2/rules_go-v0.20.2.tar.gz",
            ],
        )
    if "rules_python" not in excludes:
        http_archive(
            name = "rules_python",
            sha256 = "acbd018f11355ead06b250b352e59824fbb9e77f4874d250d230138231182c1c",
            strip_prefix = "rules_python-94677401bc56ed5d756f50b441a6a5c7f735a6d4",
            urls = ["https://github.com/bazelbuild/rules_python/archive/94677401bc56ed5d756f50b441a6a5c7f735a6d4.tar.gz"],
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
            sha256 = "7fc87f4170011201b1690326e8c16c5d802836e3a0d617d8f75c3af2b23180c4",
            urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/0.18.2/bazel-gazelle-0.18.2.tar.gz"],
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
