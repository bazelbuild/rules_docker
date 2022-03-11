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

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_library")
load("//contrib:test.bzl", "container_test")
load("//groovy:image.bzl", "groovy_image")

package(default_visibility = ["//visibility:public"])

groovy_library(
    name = "groovy_image_library",
    srcs = ["//testdata:Library.groovy"],
    deps = ["@com_google_guava_guava//jar"],
)

groovy_image(
    name = "groovy_image",
    srcs = ["//testdata:Binary.groovy"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    env = {"GROOVY_IMAGE_TEST_KEY": "groovy_image_test_value"},
    jvm_flags = ["-Dbuild.location=$(location :BUILD)"],
    layers = [":groovy_image_library"],
    main_class = "examples.images.Binary",
)

groovy_image(
    name = "groovy_classpath_as_file_image",
    srcs = ["//testdata:Binary.groovy"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    classpath_as_file = True,
    data = [":BUILD"],
    jvm_flags = ["-Dbuild.location=$(location :BUILD)"],
    layers = [":groovy_image_library"],
    main_class = "examples.images.Binary",
)

container_test(
    name = "groovy_image_test",
    configs = ["//tests/container/groovy/configs:groovy_image.yaml"],
    image = ":groovy_image",
)

container_test(
    name = "groovy_classpath_as_file_image_test",
    configs = ["//tests/container/groovy/configs:groovy_classpath_as_file_image.yaml"],
    image = ":groovy_classpath_as_file_image",
)
