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

load(
    "//container:container.bzl",
    "container_push",
    docker_build = "container_image",
    docker_bundle = "container_bundle",
    docker_flatten = "container_flatten",
    docker_image = "container_image",
    docker_layer = "container_layer",
    docker_import = "container_import",
    docker_load = "container_load",
    docker_pull = "container_pull",
    docker_repositories = "repositories",
)

def docker_push(*args, **kwargs):
  if "format" in kwargs:
    fail("Cannot override 'format' attribute on docker_push",
         attr="format")
  kwargs["format"] = "Docker"
  container_push(*args, **kwargs)
