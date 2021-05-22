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
load("//contrib:compare_ids_test.bzl", "compare_ids_test")
load("//contrib:test.bzl", "container_test")
load("//docker/package_managers:apt_key.bzl", "add_apt_key")
load("//docker/package_managers:download_pkgs.bzl", "download_pkgs")
load("//docker/package_managers:install_pkgs.bzl", "install_pkgs")

package(default_visibility = ["//visibility:public"])

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

sh_test(
    name = "download_pkgs_run_test",
    srcs = ["download_pkgs_run_test.sh"],
    data = [":test_download_pkgs.tar"],
)

add_apt_key(
    name = "ubuntu_gpg_image",
    image = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    keys = [
        "@bazel_gpg//file",
    ],
)

download_pkgs(
    name = "test_download_pkgs_with_additional_repos",
    additional_repos = [
        "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8",
    ],
    image_tar = ":ubuntu_gpg_image.tar",
    packages = [
        "bazel",
    ],
)

sh_test(
    name = "download_pkgs_with_additional_repos_run_test",
    srcs = ["download_pkgs_with_additional_repos_run_test.sh"],
    data = [":test_download_pkgs_with_additional_repos.tar"],
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
        "test_install_pkgs.build",
        "test_install_pkgs.tar",
    ],
    rule = "test_install_pkgs",
)

add_apt_key(
    name = "gpg_image",
    image = "@debian9//:builder.tar",
    keys = [
        "@bazel_gpg//file",
        "//tests/docker:launchpad_openjdk_gpg",
    ],
)

container_test(
    name = "gpg_test",
    configs = [":gpg_test.yaml"],
    image = ":gpg_image",
)

# Testing reproducibility of install_pkgs

download_pkgs(
    name = "download_pkg_git",
    image_tar = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    packages = [
        "git",
    ],
)

install_pkgs(
    name = "install_git_for_reproducibility_1",
    image_tar = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    installables_tar = ":download_pkg_git.tar",
    output_image_name = "test_install_pkgs_duplicate",
)

install_pkgs(
    name = "install_git_for_reproducibility_2",
    image_tar = "@ubuntu1604//:ubuntu1604_vanilla.tar",
    installables_tar = ":download_pkg_git.tar",
    output_image_name = "test_install_pkgs_duplicate",
)

compare_ids_test(
    name = "install_pkgs_reproducibility_test",
    images = [
        ":install_git_for_reproducibility_1",
        ":install_git_for_reproducibility_2",
    ],
)
