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

load("@io_bazel_rules_docker//contrib:test.bzl", "container_test")
load("@io_bazel_rules_docker//java:image.bzl", "java_image")

java_image(
    name = "java_app_bazel",
    srcs = [
        "image_data/Greeting.java",
        "image_data/ProjectRunner.java",
    ],
    main_class = "ProjectRunner",
)

# Tests

container_test(
    name = "java_app_bazel_test",
    configs = ["//java_app/test_configs:java_app_bazel.yaml"],
    image = ":java_app_bazel",
)

container_test(
    name = "java_app_dockerfile_test",
    configs = ["//java_app/test_configs:java_app_dockerfile.yaml"],
    driver = "tar",
    image = "@java_app_dockerfile//image:dockerfile_image",
)
