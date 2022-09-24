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

load("//contrib:test.bzl", "container_test")
load("//python3:image.bzl", "py3_image")

package(default_visibility = ["//visibility:public"])

py_library(
    name = "py_image_library",
    srcs = ["//testdata:py_image_library.py"],
    srcs_version = "PY2AND3",
)

py3_image(
    name = "py_image",
    srcs = ["//testdata:py_image.py"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    env = {"PY_IMAGE_TEST_KEY": "py_image_test_value"},
    layers = [
        ":py_image_library",
    ],
)

container_test(
    name = "py_image_test",
    configs = ["//tests/container/python/configs:py_image.yaml"],
    image = ":py_image",
)
