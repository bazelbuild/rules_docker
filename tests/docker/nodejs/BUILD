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
package(default_visibility = ["//visibility:public"])

load("//nodejs:image.bzl", "nodejs_image")
load("//contrib:test.bzl", "container_test")

nodejs_image(
    name = "nodejs_image",
    args = [
        "arg0",
        "arg1",
    ],
    data = ["//testdata:nodejs_image.js"],
    entry_point = "io_bazel_rules_docker/testdata/nodejs_image.js",
    node_modules = "@npm_deps//:node_modules",
)

nodejs_image(
    name = "nodejs_image_no_args",
    data = ["//testdata:nodejs_image.js"],
    entry_point = "io_bazel_rules_docker/testdata/nodejs_image.js",
    node_modules = "@npm_deps//:node_modules",
    # this should work without having to set args to empty list
    args = [""],
)

container_test(
    name = "nodejs_image_test",
    configs = ["//tests/docker/nodejs/configs:nodejs_image.yaml"],
    image = ":nodejs_image",
)

container_test(
    name = "nodejs_image_no_args_test",
    configs = ["//tests/docker/nodejs/configs:nodejs_image_no_args.yaml"],
    image = ":nodejs_image_no_args",
)
