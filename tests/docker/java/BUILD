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

load("//container:container.bzl", "container_image", "container_import")
load("//java:image.bzl", "java_image")
load("//contrib:test.bzl", "container_test")

java_library(
    name = "java_image_library",
    srcs = ["//testdata:Library.java"],
    deps = ["@com_google_guava_guava//jar"],
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
    jvm_flags = [
        "-XX:MaxPermSize=128M",
        "-Dbuild.location=$(location :BUILD)",
    ],
    layers = [":java_image_library"],
    main_class = "examples.images.Binary",
)

container_test(
    name = "java_image_entrypoint_test",
    configs = ["//tests/docker/java/configs:java_image_entrypoint.yaml"],
    image = ":java_image",
)
