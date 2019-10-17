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
load(
    "@io_bazel_rules_docker//docker/package_managers:download_pkgs.bzl",
    "download_pkgs",
)

package(default_visibility = ["//visibility:public"])

download_pkgs(
    name = "test_download_pkgs_at_root",
    image_tar = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    packages = [
        "curl",
        "netbase",
    ],
)

rule_test(
    name = "test_download_pkgs_at_root_rule",
    generates = [
        "test_download_pkgs_at_root",
    ],
    rule = "test_download_pkgs_at_root",
)

file_test(
    name = "test_download_pkgs_at_root_docker_run",
    file = ":test_download_pkgs_at_root",
    regexp = "image_id.* ../ubuntu1604/ubuntu1604_vanilla.tar)$",
)

file_test(
    name = "test_download_pkgs_at_root_docker_cp",
    file = ":test_download_pkgs_at_root",
    regexp = "cid:test_download_pkgs_at_root_packages.tar test_download_pkgs_at_root.tar.*",
)

file_test(
    name = "test_download_pkgs_at_root_metadata_csv",
    file = ":test_download_pkgs_at_root_metadata.csv",
    regexp = "curl",
)

sh_test(
    name = "download_pkgs_at_root_run_test",
    srcs = [":download_pkgs_at_root_run_test.sh"],
    data = [":test_download_pkgs_at_root.tar"],
)
