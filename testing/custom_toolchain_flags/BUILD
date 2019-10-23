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
    "rule_test",
)
load("@io_bazel_rules_docker//container:container.bzl", "container_image")
load("@io_bazel_rules_docker//docker/package_managers:download_pkgs.bzl", "download_pkgs")
load("@io_bazel_rules_docker//docker/package_managers:install_pkgs.bzl", "install_pkgs")
load("@io_bazel_rules_docker//docker/util:run.bzl", "container_run_and_commit", "container_run_and_extract")

package(default_visibility = ["//visibility:public"])

download_pkgs(
    name = "test_download_pkgs",
    image_tar = "@debian_base//image",
    packages = [
        "curl",
        "netbase",
    ],
)

install_pkgs(
    name = "test_install_pkgs",
    image_tar = "@debian_base//image",
    installables_tar = ":test_download_pkgs.tar",
    installation_cleanup_commands = "rm -rf /var/lib/apt/lists/*",
    output_image_name = "test_install_pkgs",
)

container_image(
    name = "test_container_image",
    base = ":test_install_pkgs.tar",
)

container_run_and_extract(
    name = "test_container_run_and_extract",
    commands = [
        "touch /foo",
    ],
    extract_file = "/foo",
    image = "@debian_base//image",
)

container_run_and_commit(
    name = "test_container_run_and_commit",
    commands = [
        "touch /foo",
    ],
    image = "@debian_base//image",
)

rule_test(
    name = "test_download_pkgs_rule",
    generates = [
        "test_download_pkgs",
    ],
    rule = "test_download_pkgs",
)

file_test(
    name = "test_custom_flag_download_pkgs",
    file = ":test_download_pkgs.sh",
    regexp = "DOCKER_FLAGS=\"--log-level=info\"",
)

rule_test(
    name = "test_install_pkgs_rule",
    generates = [
        "test_install_pkgs.build",
        "test_install_pkgs.tar",
    ],
    rule = "test_install_pkgs",
)

file_test(
    name = "test_custom_flag_install_pkgs",
    file = ":test_install_pkgs.build",
    regexp = "DOCKER_FLAGS=\"--log-level=info\"",
)

rule_test(
    name = "test_container_image_rule",
    generates = [
        "test_container_image-layer.tar",
    ],
    rule = "test_container_image",
)

file_test(
    name = "test_custom_flag_container_image",
    file = ":test_container_image.executable",
    regexp = "DOCKER_FLAGS=\"--log-level=info\"",
)

rule_test(
    name = "test_container_run_and_extract_rule",
    generates = [
        "test_container_run_and_extract.build",
        "test_container_run_and_extract/foo",
    ],
    rule = "test_container_run_and_extract",
)

file_test(
    name = "test_custom_flag_container_run_and_extract",
    file = ":test_container_run_and_extract.build",
    regexp = "DOCKER_FLAGS=\"--log-level=info\"",
)

rule_test(
    name = "test_container_run_and_commit_rule",
    generates = [
        "test_container_run_and_commit.build",
        "test_container_run_and_commit_commit.tar",
    ],
    rule = "test_container_run_and_commit",
)

file_test(
    name = "test_custom_flag_container_run_and_commit",
    file = ":test_container_run_and_commit.build",
    regexp = "DOCKER_FLAGS=\"--log-level=info\"",
)
