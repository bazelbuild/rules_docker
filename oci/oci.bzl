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
"""Rules for manipulation OCI images."""

# Expose the oci_flatten rule.
load(
    "//container:flatten.bzl",
    oci_flatten = "container_flatten",
)

# Expose the oci_import rule.
load(
    "//container:import.bzl",
    oci_import = "container_import",
)

# Expose the oci_pull repository rule.
load(
    "//container:pull.bzl",
    oci_pull = "container_pull",
)

# Expose the oci_push rule.
load("//container:push.bzl", "container_push")

def oci_push(*args, **kwargs):
  if "format" in kwargs:
    fail("Cannot override 'format' attribute on oci_push",
         attr="format")
  kwargs["format"] = "OCI"
  container_push(*args, **kwargs)
