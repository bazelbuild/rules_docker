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

load("@io_bazel_rules_docker//container:container.bzl", "container_image", "container_layer")
load("@io_bazel_rules_docker//contrib:test.bzl", "container_test")
load("@io_bazel_rules_docker//docker/util:run.bzl", "container_run_and_commit")

# Includes the gcloud installation archive
container_layer(
    name = "gcloud-layer",
    tars = [
        "@gcloud_archive//file",
    ],
)

# Build an image that uses the official bazel base image and includes the
# gcloud layer on top
container_image(
    name = "gcloud_installer",
    base = "@bazel_image//image",
    cmd = "",
    entrypoint = "",
    layers = [":gcloud-layer"],
)

# Bootstrap the container image by installing some additional
# packages and running some post install steps
container_run_and_commit(
    name = "gcloud_install",
    commands = [
        # Finalize the gcloud installation
        "/google-cloud-sdk/install.sh -q",
        # Add the gcloud binaries to PATH
        "echo 'source /google-cloud-sdk/path.bash.inc' >> ~/.bashrc",
        # Install kubernetes as a component of gcloud
        "/google-cloud-sdk/bin/gcloud components install --quiet kubectl",
        # Install Python tools
        "wget https://bootstrap.pypa.io/3.5/get-pip.py",
        "python3 get-pip.py",
        "python3 -m pip install --upgrade setuptools wheel",
    ],
    image = ":gcloud_installer.tar",
)

# Wrapper targets for the tarred images are required in order to be able to run
# commandTests in container_test targets.

container_image(
    name = "bazel_gcloud_bazel_wrapper",
    base = ":gcloud_install_commit.tar",
    env = {"PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/google-cloud-sdk/bin"},
)

container_image(
    name = "bazel_gcloud_dockerfile_wrapper",
    base = "@bazel_gcloud_dockerfile//image:dockerfile_image.tar",
)

# Tests

container_test(
    name = "bazel_gcloud_bazel_test",
    configs = ["//run_instruction_arbitrary/test_configs:bazel_gcloud.yaml"],
    image = ":bazel_gcloud_bazel_wrapper",
)

container_test(
    name = "bazel_gcloud_dockerfile_test",
    configs = ["//run_instruction_arbitrary/test_configs:bazel_gcloud.yaml"],
    image = ":bazel_gcloud_dockerfile_wrapper",
)
