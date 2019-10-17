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
    _docker_build = "container_image",
    _docker_bundle = "container_bundle",
    _docker_flatten = "container_flatten",
    _docker_image = "container_image",
    _docker_import = "container_import",
    _docker_layer = "container_layer",
    _docker_load = "container_load",
    _docker_pull = "container_pull",
)

docker_pull = _docker_pull
docker_load = _docker_load
docker_layer = _docker_layer
docker_import = _docker_import
docker_image = _docker_image
docker_flatten = _docker_flatten
docker_bundle = _docker_bundle
docker_build = _docker_build

def docker_push(*args, **kwargs):
    if "format" in kwargs:
        fail(
            "Cannot override 'format' attribute on docker_push",
            attr = "format",
        )
    kwargs["format"] = "Docker"
    container_push(*args, **kwargs)
