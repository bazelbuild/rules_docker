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

load("@io_bazel_rules_docker//python:image.bzl", "py_image")
load("@pip_deps//:requirements.bzl", "all_requirements", "requirement")

package(default_visibility = ["//testdata:__subpackages__"])

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
)

filegroup(
    name = "test-data",
    srcs = ["test"],
)

py_library(
    name = "py_image_library_using_addict",
    srcs = ["py_image_library_using_addict.py"],
    deps = [requirement("addict")],
)

# For end to end testing of py_image dependencies specified as "layers"
py_image(
    name = "py_image_using_layers",
    srcs = ["py_image_using_layers.py"],
    layers = all_requirements,
    main = "py_image_using_layers.py",
)
