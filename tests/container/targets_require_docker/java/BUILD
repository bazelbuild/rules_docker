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
    name = "java_image_test",
    configs = ["//tests/container/java/configs:java_image.yaml"],
    image = "//tests/container/java:java_image",
)

container_test(
    name = "java_runfiles_image_test",
    configs = ["//tests/container/java/configs:java_runfiles_image.yaml"],
    image = "//tests/container/java:java_runfiles_image",
)

container_test(
    name = "java_runfiles_as_lib_image_test",
    configs = ["//tests/container/java/configs:java_runfiles_as_lib_image.yaml"],
    image = "//tests/container/java:java_runfiles_as_lib_image",
)

container_test(
    name = "java_partial_entrypoint_image_test",
    configs = ["//tests/container/java/configs:java_partial_entrypoint.yaml"],
    image = "//tests/container/java:java_partial_entrypoint_image",
)

container_test(
    name = "simple_java_entrypoint_image_test",
    configs = ["//tests/container/java/configs:simple_java_entrypoint.yaml"],
    image = "//tests/container/java:simple_java_image",
)
