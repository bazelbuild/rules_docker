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

load(
    "@bazel_tools//tools/build_rules:test_rules.bzl",
    "file_test",
)

load("//docker/security:security_check.bzl", "security_check")

security_check(
    name = "security_check",
    image = "gcr.io/gcp-runtimes/ubuntu_16_0_4:latest",
)

file_test(
    name = "security_check_test",
    regexp = "tags:",
    file = ":security_check.yaml",
)

security_check(
    name = "security_check_expect_cve",
    image = "gcr.io/gcp-runtimes/ubuntu_16_0_4@sha256:ea9adca359f7f33afb6a1e0979d3f0baad15c7b765235c9b6e076f92e6a40837",
)

# If this test fails it might be the case that the vulnerability info for an
# old image is no longer available. Remove it if so and mark a TODO for
# @nlopezgi to fix.
file_test(
    name = "security_check_expect_cve_test",
    regexp = "cveMedium",
    file = ":security_check_expect_cve.yaml",
)

