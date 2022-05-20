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

load("//cc:image.bzl", "cc_image")
load("//contrib:test.bzl", "container_test")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "cc_image_library",
    srcs = ["//testdata:cc_image_library.cc"],
    hdrs = ["//testdata:cc_image_library.h"],
)

cc_image(
    name = "cc_image",
    srcs = ["//testdata:cc_image.cc"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    env = {"CC_IMAGE_TEST_KEY": "cc_image_test_value"},
    # This creates an empty layer, due to linking.
    layers = [":cc_image_library"],
)

container_test(
    name = "cc_image_test",
    configs = ["//tests/container/cc/configs:cc_image.yaml"],
    image = ":cc_image",
)
