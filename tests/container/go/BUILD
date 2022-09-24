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
load("//go:image.bzl", "go_image")

package(default_visibility = ["//visibility:public"])

go_image(
    name = "go_image",
    srcs = ["//testdata:main.go"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    env = {"GO_IMAGE_TEST_KEY": "go_image_test_value"},
    importpath = "github.com/bazelbuild/rules_docker/docker/tests/container/go",
    pure = "off",  # we should be using gcr.io/distroless/base as a base image
    tags = [
        "tag1",
        "tag2",
    ],
)

container_test(
    name = "go_image_test",
    configs = ["//tests/container/go/configs:go_image.yaml"],
    image = ":go_image",
)

go_image(
    name = "go_static_image",
    srcs = ["//testdata:main.go"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    importpath = "github.com/bazelbuild/rules_docker/docker/tests/container/go",
    pure = "on",  # we should be using gcr.io/distroless/static as a base image
    tags = [
        "tag1",
        "tag2",
    ],
)

container_test(
    name = "go_static_image_test",
    configs = ["//tests/container/go/configs:go_static_image.yaml"],
    image = ":go_static_image",
)
