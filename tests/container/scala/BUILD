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

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_library")
load("//contrib:test.bzl", "container_test")
load("//scala:image.bzl", "scala_image")

package(default_visibility = ["//visibility:public"])

scala_library(
    name = "scala_image_library",
    srcs = ["//testdata:Library.scala"],
    deps = ["@com_google_guava_guava//jar"],
)

scala_image(
    name = "scala_image",
    srcs = ["//testdata:Binary.scala"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    env = {"SCALA_IMAGE_TEST_KEY": "scala_image_test_value"},
    jvm_flags = ["-Dbuild.location=$(location :BUILD)"],
    layers = [":scala_image_library"],
    main_class = "examples.images.Binary",
)

container_test(
    name = "scala_image_test",
    configs = ["//tests/container/scala/configs:scala_image.yaml"],
    image = ":scala_image",
)

scala_image(
    name = "scala_classpath_as_file_image",
    srcs = ["//testdata:Binary.scala"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    classpath_as_file = True,
    data = [":BUILD"],
    jvm_flags = ["-Dbuild.location=$(location :BUILD)"],
    layers = [":scala_image_library"],
    main_class = "examples.images.Binary",
)

container_test(
    name = "scala_classpath_as_file_image_test",
    configs = ["//tests/container/scala/configs:scala_classpath_as_file_image.yaml"],
    image = ":scala_classpath_as_file_image",
)
