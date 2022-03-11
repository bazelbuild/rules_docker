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
load("//rust:image.bzl", "rust_image")

package(default_visibility = ["//visibility:public"])

rust_image(
    name = "rust_image",
    srcs = ["//testdata:main.rs"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    env = {"RUST_IMAGE_TEST_KEY": "rust_image_test_value"},
)

container_test(
    name = "rust_image_test",
    configs = ["//tests/container/rust/configs:rust_image.yaml"],
    image = ":rust_image",
)
