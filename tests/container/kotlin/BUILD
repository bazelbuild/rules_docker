# Copyright 2020 The Bazel Authors. All rights reserved.
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
load("//kotlin:image.bzl", "kt_jvm_image")

package(default_visibility = ["//visibility:public"])

kt_jvm_image(
    name = "kt_jvm_image",
    srcs = [
        "//testdata:Binary.kt",
        "//testdata:Library.kt",
    ],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    env = {"KT_JVM_IMAGE_TEST_KEY": "kt_jvm_image_test_value"},
    jvm_flags = ["-Dbuild.location=$(location :BUILD)"],
    main_class = "examples.images.Binary",
    deps = [],
)

kt_jvm_image(
    name = "kt_jvm_classpath_as_file_image",
    srcs = [
        "//testdata:Binary.kt",
        "//testdata:Library.kt",
    ],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    classpath_as_file = True,
    data = [":BUILD"],
    jvm_flags = ["-Dbuild.location=$(location :BUILD)"],
    main_class = "examples.images.Binary",
    deps = [],
)

container_test(
    name = "kotlin_image_test",
    configs = ["//tests/container/kotlin/configs:kt_jvm_image.yaml"],
    image = ":kt_jvm_image",
)

container_test(
    name = "kotlin_classpath_as_file_image_test",
    configs = ["//tests/container/kotlin/configs:kt_jvm_classpath_as_file_image.yaml"],
    image = ":kt_jvm_classpath_as_file_image",
)
