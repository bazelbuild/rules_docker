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

load("@bazel_tools//tools/build_rules:test_rules.bzl", "file_test")
load("//container:container.bzl", "container_image")
load("//contrib:test.bzl", "container_test")

file_test(
    name = "test_extracted_file",
    file = "//tests/docker/util:test_container_extract/foo.txt",
    regexp = "test",
)

container_image(
    name = "test_container_commit_image",
    base = "//tests/docker/util:test_container_commit",
)

container_test(
    name = "test_container_commit_metadata",
    configs = [":container_commit.yaml"],
    image = ":test_container_commit_image",
)
