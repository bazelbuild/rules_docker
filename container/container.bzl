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
"""Rules for manipulating container images."""

load("//container:bundle.bzl", _container_bundle = "container_bundle")
load("//container:flatten.bzl", _container_flatten = "container_flatten")
load("//container:image.bzl", _container_image = "container_image", _image = "image")
load("//container:import.bzl", _container_import = "container_import")
load("//container:layer.bzl", _container_layer = "container_layer")
load("//container:load.bzl", _container_load = "container_load")
load("//container:pull.bzl", _container_pull = "container_pull")
load("//container:push.bzl", _container_push = "container_push")

# Explicitly re-export the functions
container_bundle = _container_bundle
container_flatten = _container_flatten
container_image = _container_image
image = _image
container_layer = _container_layer
container_import = _container_import
container_pull = _container_pull
container_push = _container_push
container_load = _container_load

container = struct(
    image = image,
)
