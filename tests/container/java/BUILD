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
load("//java:image.bzl", "java_image", "java_layer")

package(default_visibility = ["//visibility:public"])

java_library(
    name = "java_image_library",
    srcs = ["//testdata:Library.java"],
    deps = ["@com_google_guava_guava//jar"],
)

java_library(
    name = "java_bin_as_lib",
    srcs = ["//testdata:Binary.java"],
    deps = ["//tests/container/java:java_image_library"],
)

java_image(
    name = "simple_java_image",
    main_class = "examples.images.Binary",
    runtime_deps = [":java_bin_as_lib"],
)

java_image(
    name = "java_image",
    srcs = ["//testdata:Binary.java"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    env = {"JAVA_IMAGE_TEST_KEY": "java_image_test_value"},
    jvm_flags = [
        "-Dbuild.location=$(location :BUILD)",
    ],
    layers = [":java_image_library"],
    main_class = "examples.images.Binary",
)

java_layer(
    name = "java_image_external_deps_layer",
    filter = "@",
    deps = [":java_image_library"],
)

java_image(
    name = "java_image_complex_external_deps",
    srcs = ["//testdata:Binary.java"],
    layers = [":java_image_external_deps_layer"],
    main_class = "examples.images.Binary",
    deps = [":java_image_library"],
)

java_image(
    name = "java_classpath_as_file_image",
    srcs = ["//testdata:Binary.java"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    classpath_as_file = True,
    data = [":BUILD"],
    jvm_flags = [
        "-Dbuild.location=$(location :BUILD)",
    ],
    layers = [":java_image_library"],
    main_class = "examples.images.Binary",
)

java_image(
    name = "java_runfiles_image",
    srcs = ["//testdata:Runfiles.java"],
    data = [
        "//testdata:foo",
    ],
    main_class = "examples.images.Runfiles",
    deps = [
        "@bazel_tools//tools/java/runfiles",
    ],
)

java_library(
    name = "java_runfiles_as_lib",
    srcs = ["//testdata:Runfiles.java"],
    data = [
        "//testdata:foo",
    ],
    deps = [
        "@bazel_tools//tools/java/runfiles",
    ],
)

java_image(
    name = "java_runfiles_as_lib_image",
    main_class = "examples.images.Runfiles",
    runtime_deps = [":java_runfiles_as_lib"],
)

java_image(
    name = "java_partial_entrypoint_image",
    runtime_deps = [":java_bin_as_lib"],
)

container_test(
    name = "java_image_test",
    configs = ["//tests/container/java/configs:java_image.yaml"],
    image = ":java_image",
)

container_test(
    name = "java_image_complex_external_deps_test",
    configs = ["//tests/container/java/configs:java_image_complex_external_deps.yaml"],
    image = ":java_image_complex_external_deps",
)

container_test(
    name = "java_classpath_as_file_image_test",
    configs = ["//tests/container/java/configs:java_classpath_as_file_image.yaml"],
    image = ":java_classpath_as_file_image",
)

container_test(
    name = "java_runfiles_image_test",
    configs = ["//tests/container/java/configs:java_runfiles_image.yaml"],
    image = ":java_runfiles_image",
)

container_test(
    name = "java_runfiles_as_lib_image_test",
    configs = ["//tests/container/java/configs:java_runfiles_as_lib_image.yaml"],
    image = ":java_runfiles_as_lib_image",
)

container_test(
    name = "java_partial_entrypoint_image_test",
    configs = ["//tests/container/java/configs:java_partial_entrypoint.yaml"],
    image = ":java_partial_entrypoint_image",
)

container_test(
    name = "simple_java_entrypoint_image_test",
    configs = ["//tests/container/java/configs:simple_java_entrypoint.yaml"],
    image = ":simple_java_image",
)
