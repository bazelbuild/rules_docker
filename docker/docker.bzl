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
"""Rules for manipulation Docker images."""

# Alias docker_build and docker_bundle for now, so folks can move to
# referencing this before it becomes the source of truth.
# TODO(mattmoor): Add docker_bundle once it is a part of a Bazel release.
load("@bazel_tools//tools/build_defs/docker:docker.bzl", "docker_build")

# Expose the docker_pull repository rule.
load(":pull.bzl", "docker_pull")

# Expose the docker_push rule.
load(":push.bzl", "docker_push")


def docker_repositories():
  """Download dependencies of docker rules."""
  native.http_file(
    name = "puller",
    url = "https://storage.googleapis.com/containerregistry-releases/v0.0.1/puller.par",
    sha256 = "ad078d2e3041b03fb28f3a99b30f1834da602883867d2daa3535f24928fdcfbd",
    executable = True,
  )

  native.http_file(
    name = "pusher",
    url = "https://storage.googleapis.com/containerregistry-releases/v0.0.1/pusher.par",
    sha256 = "5b77f4060a1c20e6cbeb3ca417f90a19d180390f63bc90f5b9ae44e919e99308",
    executable = True,
  )
