# Copyright 2018 The Bazel Authors. All rights reserved.
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
"""
This BUILD file is auto-generated from toolchains/docker/BUILD.tpl
"""
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_docker//toolchains/docker:toolchain.bzl", "docker_toolchain")

docker_toolchain(
    name = "toolchain",
    client_config = "%{DOCKER_CONFIG}",
    %{BUILD_TAR_ATTR}
    %{GZIP_ATTR}
    %{TOOL_ATTR}
    docker_flags = ["%{DOCKER_FLAGS}"],
    %{XZ_ATTR}
)
