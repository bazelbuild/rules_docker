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
    url = "https://storage.googleapis.com/containerregistry-releases/v0.0.2/puller.par",
    sha256 = "a69b44222148b8a740d557e93f6227e25e8aa1c7ac2aab137c66752cddf2a754",
    executable = True,
  )

  native.http_file(
    name = "pusher",
    url = "https://storage.googleapis.com/containerregistry-releases/v0.0.2/pusher.par",
    sha256 = "73f511f94d2a6ed870c51aaf50b720a1b205970d6fd930078abefd4bd1a0ab99",
    executable = True,
  )
