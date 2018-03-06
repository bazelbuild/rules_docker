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

# Current nodejs_image layers:
# - 0: node.js runtime
# - 1: node_modules
# - 2: application

container_test(
    name = "structure_test.0",
    configs = ["//tests/nodejs/configs:test.0.yaml"],
    driver = "tar",
    image = "//testdata:nodejs_image.0",
)

container_test(
    name = "structure_test.1",
    configs = ["//tests/nodejs/configs:test.1.yaml"],
    driver = "tar",
    image = "//testdata:nodejs_image.1",
)

container_test(
    name = "structure_test",
    configs = ["//tests/nodejs/configs:test.yaml"],
    driver = "tar",
    image = "//testdata:nodejs_image",
)
