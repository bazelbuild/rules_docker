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

container_test(
    name = "nodejs_image_test",
    configs = [":nodejs_image.yaml"],
    image = "//tests/container/nodejs:nodejs_image",
)

container_test(
    name = "nodejs_image_list_with_empty_string_args_test",
    configs = [":nodejs_image_list_with_empty_string_args.yaml"],
    image = "//tests/container/nodejs:nodejs_image_list_with_empty_string_args",
)

container_test(
    name = "nodejs_image_no_args_test",
    configs = [":nodejs_image_no_args.yaml"],
    image = "//tests/container/nodejs:nodejs_image_no_args",
)

container_test(
    name = "nodejs_image_empty_list_args_test",
    configs = [":nodejs_image_empty_list_args.yaml"],
    image = "//tests/container/nodejs:nodejs_image_empty_list_args",
)

container_test(
    name = "nodejs_image_none_args_test",
    configs = [":nodejs_image_none_args.yaml"],
    image = "//tests/container/nodejs:nodejs_image_none_args",
)

container_test(
    name = "nodejs_image_custom_binary_test",
    configs = [":nodejs_image_custom_binary.yaml"],
    image = "//tests/container/nodejs:nodejs_image_custom_binary",
)

container_test(
    name = "nodejs_image_custom_binary_with_args_test",
    configs = [":nodejs_image_custom_binary_with_args.yaml"],
    image = "//tests/container/nodejs:nodejs_image_custom_binary_with_args",
)
