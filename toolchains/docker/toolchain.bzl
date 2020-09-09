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
        "client_config": "A custom directory for the docker client " +
                         "config.json. If DOCKER_CONFIG is not specified, " +
                         "the value of the DOCKER_CONFIG environment variable " +
                         "will be used. DOCKER_CONFIG is not defined, the " +
                         "home directory will be used.",
        "docker_flags": "Additional flags to the docker command",
        "gzip_path": "Optional path to the gzip binary.",
        "gzip_target": "Optional Bazel target for the gzip tool. " +
                       "Should only be set if gzip_path is unset.",
        "tool_path": "Path to the docker executable",
        "xz_path": "Optional path to the xz binary. This is used by " +
                   "build_tar.py when the Python lzma module is unavailable. " +
                   "If not set found via which.",
    },
)

def _docker_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        info = DockerToolchainInfo(
            docker_flags = ctx.attr.docker_flags,
            client_config = ctx.attr.client_config,
            gzip_path = ctx.attr.gzip_path,
            gzip_target = ctx.attr.gzip_target,
            tool_path = ctx.attr.tool_path,
            xz_path = ctx.attr.xz_path,
        ),
    )
    return [toolchain_info]

# Rule used by the docker toolchain rule to specify a path to the docker
# binary
docker_toolchain = rule(
    implementation = _docker_toolchain_impl,
    attrs = {
        "client_config": attr.string(
            default = "",
            doc = "A custom directory for the docker client config.json. If " +
                  "DOCKER_CONFIG is not specified, the value of the " +
                  "DOCKER_CONFIG environment variable will be used. " +
                  "DOCKER_CONFIG is not defined, the home directory will be " +
                  "used.",
        ),
        "docker_flags": attr.string_list(
            doc = "Additional flags to the docker command",
        ),
        "gzip_path": attr.string(
            doc = "Path to the gzip binary. " +
                  "Should only be set if gzip_target is unset.",
        ),
        "gzip_target": attr.label(
            allow_files = True,
            doc = "Bazel target for the gzip tool. " +
                  "Should only be set if gzip_path is unset.",
            cfg = "host",
            executable = True,
        ),
        "tool_path": attr.string(
            doc = "Path to the docker binary.",
        ),
        "xz_path": attr.string(
            doc = "Optional path to the xz binary. This is used by " +
                  "build_tar.py when the Python lzma module is unavailable.",
        ),
    },
)

def _toolchain_configure_impl(repository_ctx):
    if repository_ctx.attr.gzip_target and repository_ctx.attr.gzip_path:
        fail("Only one of gzip_target or gzip_path can be set.")
    tool_path = ""
    if repository_ctx.attr.docker_path:
        tool_path = repository_ctx.attr.docker_path
    elif repository_ctx.which("docker"):
        tool_path = repository_ctx.which("docker")

    xz_path = ""
    if repository_ctx.attr.xz_path:
        xz_path = repository_ctx.attr.xz_path
    elif repository_ctx.which("xz"):
        xz_path = repository_ctx.which("xz")

    gzip_attr = ""
    if repository_ctx.attr.gzip_target:
        gzip_attr = "gzip_target = \"%s\"," % repository_ctx.attr.gzip_target
    elif repository_ctx.attr.gzip_path:
        gzip_attr = "gzip_path = \"%s\"," % repository_ctx.attr.gzip_path
    docker_flags = []
    docker_flags += repository_ctx.attr.docker_flags

    # If client_config is not set we need to pass an empty string to the
    # template.
    client_config = repository_ctx.attr.client_config or ""
    repository_ctx.template(
        "BUILD",
        Label("@io_bazel_rules_docker//toolchains/docker:BUILD.tpl"),
        {
            "%{DOCKER_CONFIG}": "%s" % client_config,
            "%{DOCKER_FLAGS}": "%s" % "\", \"".join(docker_flags),
            "%{DOCKER_TOOL}": "%s" % tool_path,
            "%{GZIP_ATTR}": "%s" % gzip_attr,
            "%{XZ_TOOL_PATH}": "%s" % xz_path,
        },
        False,
    )

    # Generate a custom variant authenticated version of the repository rule
    # container_push if a custom docker client config directory was specified.
    if client_config != "":
        repository_ctx.template(
            "pull.bzl",
            Label("@io_bazel_rules_docker//toolchains/docker:pull.bzl.tpl"),
            {
                "%{docker_client_config}": "%s" % client_config,
            },
            False,
        )

# Repository rule to generate a docker_toolchain target
toolchain_configure = repository_rule(
    attrs = {
        "client_config": attr.string(
            mandatory = False,
            doc = "A custom directory for the docker client " +
                  "config.json. If DOCKER_CONFIG is not specified, the value " +
                  "of the DOCKER_CONFIG environment variable will be used. " +
                  "DOCKER_CONFIG is not defined, the default set for the " +
                  "docker tool (typically, the home directory) will be " +
                  "used.",
        ),
        "docker_flags": attr.string_list(
            mandatory = False,
            doc = "List of additional flag arguments to the docker command.",
        ),
        "docker_path": attr.string(
            mandatory = False,
            doc = "The full path to the docker binary. If not specified, it will " +
                  "be searched for in the path. If not available, running commands " +
                  "that require docker (e.g., incremental load) will fail.",
        ),
        "gzip_path": attr.string(
            mandatory = False,
            doc = "The full path to the gzip binary. If not specified, a tool will " +
                  "be compiled and used.",
        ),
        "gzip_target": attr.label(
            executable = True,
            cfg = "host",
            allow_files = True,
            mandatory = False,
            doc = "The bazel target for the gzip tool. " +
                  "Can only be set if gzip_path is not set.",
        ),
        "xz_path": attr.string(
            mandatory = False,
            doc = "The full path to the xz binary. If not specified, it will " +
                  "be searched for in the path. If not available, running commands " +
                  "that use xz will fail.",
        ),
    },
    environ = [
        "PATH",
    ],
    implementation = _toolchain_configure_impl,
)
