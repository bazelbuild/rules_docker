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
"""
This module defines docker toolchain rules
"""

DockerToolchainInfo = provider(
    doc = "Docker toolchain rule parameters",
    fields = {
        "tool_path": "Path to the docker executable",
    },
)

def _docker_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        info = DockerToolchainInfo(
            tool_path = ctx.attr.tool_path,
        ),
    )
    return [toolchain_info]

# Regular rule used by the docker toolchain rule to specify a path to the docker
# binary
docker_toolchain = rule(
    implementation = _docker_toolchain_impl,
    attrs = {
        "tool_path": attr.string(
            doc = "Path to the docker binary",
        ),
    },
)

def _toolchain_configure_impl(repository_ctx):
    tool_path = repository_ctx.which("docker")
    repository_ctx.template(
        "BUILD",
        Label("@io_bazel_rules_docker//toolchains/docker:BUILD.tpl"),
        {
            "%{DOCKER_TOOL}": "%s" % tool_path,
        },
        False,
    )

# Repository rule to automatically generate a docker_toolchain target
toolchain_configure = repository_rule(
    implementation = _toolchain_configure_impl,
)
