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

load("@io_bazel_rules_docker//container:container.bzl", "container_image")
load("@io_bazel_rules_docker//contrib:test.bzl", "container_test")
load("@io_bazel_rules_docker//docker/package_managers:download_pkgs.bzl", "download_pkgs")
load("@io_bazel_rules_docker//docker/package_managers:install_pkgs.bzl", "install_pkgs")

download_pkgs(
    name = "java_and_python_pkgs",
    image_tar = "@ubuntu1604//image",
    packages = [
        "openjdk-8-jdk",
        "python",
        "python-dev",
        "python-pip",
        "python3",
        "python3-pip",
    ],
)

install_pkgs(
    name = "java_python_pkgs_image",
    image_tar = "@ubuntu1604//image",
    installables_tar = ":java_and_python_pkgs.tar",
    installation_cleanup_commands = "rm -rf /var/lib/apt/lists/*",
    output_image_name = "java_python_pkgs_image",
)

# Wrapper targets for the tarred images are required in order to be able to run
# commandTests in container_test targets.

container_image(
    name = "java_python_bazel_wrapper",
    base = ":java_python_pkgs_image.tar",
)

container_image(
    name = "java_python_dockerfile_wrapper",
    base = "@java_python_dockerfile//image:dockerfile_image.tar",
)

# Tests

container_test(
    name = "java_python_bazel_test",
    configs = ["//run_instruction_apt_pkgs/test_configs:java_python.yaml"],
    image = ":java_python_bazel_wrapper",
)

container_test(
    name = "java_python_dockerfile_test",
    configs = ["//run_instruction_apt_pkgs/test_configs:java_python.yaml"],
    image = ":java_python_dockerfile_wrapper",
)
