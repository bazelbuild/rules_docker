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
"""Provides functions to pull the images used in this repository."""

load("//container:container.bzl", "container_pull")

_REGISTRY = "l.gcr.io"

def images():
    excludes = native.existing_rules().keys()

    if "bazel_latest" not in excludes:
        container_pull(
            name = "bazel_latest",
            registry = _REGISTRY,
            repository = "google/bazel",
            tag = "latest",
        )

    if "bazel_0271" not in excludes:
        container_pull(
            name = "bazel_0271",
            registry = _REGISTRY,
            repository = "google/bazel",
            digest = "sha256:436708ebb76c0089b94c46adac5d3332adb8c98ef8f24cb32274400d01bde9e3",
        )
