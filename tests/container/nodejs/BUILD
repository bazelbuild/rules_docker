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

load("@build_bazel_rules_nodejs//:index.bzl", "nodejs_binary")
load("//contrib:test.bzl", "container_test")
load("//nodejs:image.bzl", "nodejs_image")

package(default_visibility = ["//visibility:public"])

# Docker Cmd value should be `["arg0", "arg1"]`.
nodejs_image(
    name = "nodejs_image",
    args = [
        "arg0",
        "arg1",
    ],
    data = [
        "//testdata:nodejs_image.js",
        "//testdata:nodejs_image_lib",
        "@npm//jsesc",
    ],
    entry_point = "@io_bazel_rules_docker//testdata:nodejs_image.js",
    env = {"NODEJS_IMAGE_TEST_KEY": "nodejs_image_test_value"},
)

nodejs_image(
    name = "nodejs_image_with_launcher",
    args = [
        "arg0",
        "arg1",
    ],
    data = [
        "//testdata:nodejs_image.js",
        "//testdata:nodejs_image_lib",
        "@npm//jsesc",
    ],
    entry_point = "@io_bazel_rules_docker//testdata:nodejs_image.js",
    launcher = "launcher.sh",
)

nodejs_image(
    name = "nodejs_image_with_launcher_args",
    args = [
        "arg0",
        "arg1",
    ],
    data = [
        "//testdata:nodejs_image.js",
        "//testdata:nodejs_image_lib",
        "@npm//jsesc",
    ],
    entry_point = "@io_bazel_rules_docker//testdata:nodejs_image.js",
    launcher = "launcher.sh",
    launcher_args = [
        "foo",
        "bar",
    ],
)

# Docker Cmd value should be `[""]`.
nodejs_image(
    name = "nodejs_image_list_with_empty_string_args",
    args = [""],
    data = [
        "//testdata:nodejs_image.js",
        "//testdata:nodejs_image_lib",
        "@npm//jsesc",
    ],
    entry_point = "@io_bazel_rules_docker//testdata:nodejs_image.js",
)

# Docker Cmd value should be `null`.
nodejs_image(
    name = "nodejs_image_no_args",
    data = [
        "//testdata:nodejs_image.js",
        "//testdata:nodejs_image_lib",
        "@npm//jsesc",
    ],
    entry_point = "@io_bazel_rules_docker//testdata:nodejs_image.js",
)

# Docker Cmd value should be `null`.
nodejs_image(
    name = "nodejs_image_empty_list_args",
    args = [],
    data = [
        "//testdata:nodejs_image.js",
        "//testdata:nodejs_image_lib",
        "@npm//jsesc",
    ],
    entry_point = "@io_bazel_rules_docker//testdata:nodejs_image.js",
)

# Docker Cmd value should be `null`.
nodejs_image(
    name = "nodejs_image_none_args",
    args = None,
    data = [
        "//testdata:nodejs_image.js",
        "//testdata:nodejs_image_lib",
        "@npm//jsesc",
    ],
    entry_point = "@io_bazel_rules_docker//testdata:nodejs_image.js",
)

nodejs_binary(
    name = "my_custom_binary",
    args = [
        "arg0",
        "arg1",
    ],
    data = [
        "//testdata:nodejs_image.js",
        "//testdata:nodejs_image_lib",
        "@npm//jsesc",
    ],
    entry_point = "@io_bazel_rules_docker//testdata:nodejs_image.js",
)

nodejs_image(
    name = "nodejs_image_custom_binary",
    binary = ":my_custom_binary",
)

nodejs_image(
    name = "nodejs_image_custom_binary_with_args",
    args = [
        "arg0",
        "arg1",
    ],
    binary = ":my_custom_binary",
)

container_test(
    name = "nodejs_image_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image.yaml"],
    image = ":nodejs_image",
)

container_test(
    name = "nodejs_image_with_launcher_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image_with_launcher.yaml"],
    image = ":nodejs_image_with_launcher",
)

container_test(
    name = "nodejs_image_with_launcher_args_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image_with_launcher_args.yaml"],
    image = ":nodejs_image_with_launcher_args",
)

container_test(
    name = "nodejs_image_list_with_empty_string_args_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image_list_with_empty_string_args.yaml"],
    image = ":nodejs_image_list_with_empty_string_args",
)

container_test(
    name = "nodejs_image_no_args_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image_no_args.yaml"],
    image = ":nodejs_image_no_args",
)

container_test(
    name = "nodejs_image_empty_list_args_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image_empty_list_args.yaml"],
    image = ":nodejs_image_empty_list_args",
)

container_test(
    name = "nodejs_image_none_args_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image_none_args.yaml"],
    image = ":nodejs_image_none_args",
)

container_test(
    name = "nodejs_image_custom_binary_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image_custom_binary.yaml"],
    image = ":nodejs_image_custom_binary",
)

container_test(
    name = "nodejs_image_custom_binary_with_args_test",
    configs = ["//tests/container/nodejs/configs:nodejs_image_custom_binary_with_args.yaml"],
    image = ":nodejs_image_custom_binary_with_args",
)
