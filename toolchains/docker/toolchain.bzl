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
        "client_config": """"A custom directory for the docker client config.json. If left unspecified, the value of the DOCKER_CONFIG environment variable will be used. DOCKER_CONFIG is not defined, the home directory will be used.""",
    },
)

def _docker_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        info = DockerToolchainInfo(
            tool_path = ctx.attr.tool_path,
            client_config = ctx.attr.client_config,
        ),
    )
    return [toolchain_info]

# Rule used by the docker toolchain rule to specify a path to the docker
# binary
docker_toolchain = rule(
    implementation = _docker_toolchain_impl,
    attrs = {
        "tool_path": attr.string(
            doc = "Path to the docker binary",
        ),
        "client_config": attr.string(
            default = "",
            doc = """"A custom directory for the docker client config.json. If left unspecified, the value of the DOCKER_CONFIG environment variable will be used. DOCKER_CONFIG is not defined, the home directory will be used.""",
        ),
    },
)

def _toolchain_configure_impl(repository_ctx):
    tool_path = repository_ctx.which("docker")

    # client_config could be None
    client_config = repository_ctx.attr.client_config or ""
    repository_ctx.template(
        "BUILD",
        Label("@io_bazel_rules_docker//toolchains/docker:BUILD.tpl"),
        {
            "%{DOCKER_TOOL}": "%s" % tool_path,
            "%{DOCKER_CONFIG}": "%s" % client_config,
        },
        False,
    )

# Repository rule to generate a docker_toolchain target
toolchain_configure = repository_rule(
    attrs = {
        "client_config": attr.string(
            mandatory = False,
            doc = "A custom directory for the docker client config.json. If left unspecified, the value of the DOCKER_CONFIG environment variable will be used. DOCKER_CONFIG is not defined, the home directory will be used.",
        ),
    },
    implementation = _toolchain_configure_impl,
)
