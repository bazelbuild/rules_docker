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

load(
    "@bazel_tools//tools/build_rules:test_rules.bzl",
    "file_test",
    "rule_test",
)
load("//docker/package_managers:download_pkgs.bzl", "download_pkgs")
load("//docker/package_managers:install_pkgs.bzl", "install_pkgs")

download_pkgs(
    name = "test_download_pkgs",
    image_tar = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    packages = [
        "curl",
        "netbase",
    ],
)

rule_test(
    name = "test_download_pkgs_rule",
    generates = [
        "test_download_pkgs",
    ],
    rule = "test_download_pkgs",
)

file_test(
    name = "test_download_pkgs_docker_run",
    file = ":test_download_pkgs",
    regexp = "image_id.* ../ubuntu1604/ubuntu1604_vanilla.tar)$",
)

file_test(
    name = "test_download_pkgs_docker_cp",
    file = ":test_download_pkgs",
    regexp = "cid:test_download_pkgs_packages.tar tests/docker/package_managers/test_download_pkgs.tar.*",
)

install_pkgs(
    name = "test_install_pkgs",
    image_tar = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    installables_tar = ":test_download_pkgs.tar",
    output_image_name = "test_install_pkgs",
)

rule_test(
    name = "test_install_pkgs_rule",
    generates = [
        "test_install_pkgs.tar",
    ],
    rule = "test_install_pkgs",
)
