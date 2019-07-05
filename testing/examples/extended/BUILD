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

container_image(
    name = "extended_alpine",
    base = "@alpine_linux_amd64//image",
    cmd = ["World"],
    entrypoint = [
        "echo",
        "Hello",
    ],
    env = {
        "envVar": "My environment variable",
        "xyz": "321",
    },
    files = [
        "//extended/image_data:Data_file.txt",
        "//extended/image_data:More_data.txt",
        "//extended/image_data:file_to_copy.txt",
    ],
    labels = {
        "desc": "Description for version 7.7",
        "version": "7.7",
    },
    ports = [
        "8080/tcp",
        "9876/udp",
    ],
    symlinks = {
        "/usr/More_data.txt": "/More_data.txt",
    },
    tars = ["//extended/image_data:tarfile.tar"],
    volumes = [
        "/myVol1",
        "/usr/myVol2",
    ],
)

# Tests

container_test(
    name = "extended_alpine_bazel_test",
    configs = ["//extended/test_configs:extended_alpine.yaml"],
    image = ":extended_alpine",
)

container_test(
    name = "extended_alpine_dockerfile_test",
    configs = ["//extended/test_configs:extended_alpine.yaml"],
    driver = "tar",
    image = "@extended_alpine_dockerfile//image:dockerfile_image",
)
