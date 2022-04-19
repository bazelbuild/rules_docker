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
        "build_tar_target": "Optional Bazel target for the build_tar tool",
        "client_config": "A custom directory for the docker client " +
                         "config.json. If this is not specified, " +
                         "the value of the DOCKER_CONFIG environment variable " +
                         "will be used. If DOCKER_CONFIG is not defined, the " +
                         "home directory will be used.",
        "docker_flags": "Additional flags to the docker command",
        "gzip_path": "Optional path to the gzip binary.",
        "gzip_target": "Optional Bazel target for the gzip tool. " +
                       "Should only be set if gzip_path is unset.",
        "tool_path": "Path to the docker executable",
        "tool_target": "Bazel target for the docker tool. " +
                       "Should only be set if tool_path is unset.",
        "xz_path": "Optional path to the xz binary. This is used by " +
                   "build_tar.py when the Python lzma module is unavailable. " +
                   "If not set found via which.",
        "xz_target": "Optional Bazel target for the xz tool. " +
                     "Should only be set if xz_path is unset.",
    },
)

def _docker_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        info = DockerToolchainInfo(
            build_tar_target = ctx.attr.build_tar_target,
            docker_flags = ctx.attr.docker_flags,
            client_config = ctx.attr.client_config,
            gzip_path = ctx.attr.gzip_path,
            gzip_target = ctx.attr.gzip_target,
            tool_path = ctx.attr.tool_path,
            tool_target = ctx.attr.tool_target,
            xz_path = ctx.attr.xz_path,
            xz_target = ctx.attr.xz_target,
        ),
    )
    return [toolchain_info]

# Rule used by the docker toolchain rule to specify a path to the docker
# binary
docker_toolchain = rule(
    implementation = _docker_toolchain_impl,
    attrs = {
        "build_tar_target": attr.label(
            allow_files = True,
            doc = "Bazel target for the build_tar tool.",
            cfg = "host",
            executable = True,
        ),
        # client_config cannot be a Bazel label because this attribute will be used in
        # container_push's implmentation to get the path. Because container_push is
        # a regular Bazel rule, it cannot convert a Label into an absolute path.
        # toolchain_configure is responsible for generating this attribute from a Label.
        "client_config": attr.string(
            default = "",
            doc = "An absolute path to a custom directory for the docker client " +
                  "config.json. If this is not specified, the value of the " +
                  "DOCKER_CONFIG environment variable will be used. If " +
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
        "tool_target": attr.label(
            allow_files = True,
            doc = "Bazel target for the docker tool. " +
                  "Should only be set if tool_path is unset.",
            cfg = "host",
            executable = True,
        ),
        "xz_path": attr.string(
            doc = "Optional path to the xz binary. This is used by " +
                  "build_tar.py when the Python lzma module is unavailable.",
        ),
        "xz_target": attr.label(
            allow_files = True,
            doc = "Bazel target for the xz tool. " +
                  "Should only be set if xz_path is unset.",
            cfg = "host",
            executable = True,
        ),
    },
)

def _toolchain_configure_impl(repository_ctx):
    if repository_ctx.attr.docker_target and repository_ctx.attr.docker_path:
        fail("Only one of docker_target or docker_path can be set.")
    if repository_ctx.attr.gzip_target and repository_ctx.attr.gzip_path:
        fail("Only one of gzip_target or gzip_path can be set.")
    if repository_ctx.attr.xz_target and repository_ctx.attr.xz_path:
        fail("Only one of xz_target or xz_path can be set.")

    tool_attr = ""
    if repository_ctx.attr.docker_target:
        tool_attr = "tool_target = \"%s\"," % repository_ctx.attr.tool_target
    elif repository_ctx.attr.docker_path:
        tool_attr = "tool_path = \"%s\"," % repository_ctx.attr.docker_path
    elif repository_ctx.which("docker"):
        tool_attr = "tool_path = \"%s\"," % repository_ctx.which("docker")

    xz_attr = ""
    if repository_ctx.attr.xz_target:
        xz_attr = "xz_target = \"%s\"," % repository_ctx.attr.xz_target
    elif repository_ctx.attr.xz_path:
        xz_attr = "xz_path = \"%s\"," % repository_ctx.attr.xz_path
    elif repository_ctx.which("xz"):
        xz_attr = "xz_path = \"%s\"," % repository_ctx.which("xz")

    gzip_attr = ""
    if repository_ctx.attr.gzip_target:
        gzip_attr = "gzip_target = \"%s\"," % repository_ctx.attr.gzip_target
    elif repository_ctx.attr.gzip_path:
        gzip_attr = "gzip_path = \"%s\"," % repository_ctx.attr.gzip_path
    docker_flags = []
    docker_flags += repository_ctx.attr.docker_flags

    build_tar_attr = ""
    if repository_ctx.attr.build_tar_target:
        build_tar_attr = "build_tar_target = \"%s\"," % repository_ctx.attr.build_tar_target

    if repository_ctx.attr.client_config:
        # Generate a custom variant authenticated version of the repository rule
        # container_push if a custom docker client config directory was specified.
        repository_ctx.template(
            "pull.bzl",
            Label("@io_bazel_rules_docker//toolchains/docker:pull.bzl.tpl"),
            {
                "%{docker_client_config}": str(repository_ctx.attr.client_config),
                "%{cred_helpers}": str(repository_ctx.attr.cred_helpers),
            },
            False,
        )
        client_config_dir = repository_ctx.path(repository_ctx.attr.client_config).dirname
    else:
        # If client_config is not set we need to pass an empty string to the
        # toolchain.
        client_config_dir = ""

    repository_ctx.template(
        "BUILD",
        Label("@io_bazel_rules_docker//toolchains/docker:BUILD.tpl"),
        {
            "%{BUILD_TAR_ATTR}": "%s" % build_tar_attr,
            "%{DOCKER_CONFIG}": "%s" % client_config_dir,
            "%{DOCKER_FLAGS}": "%s" % "\", \"".join(docker_flags),
            "%{TOOL_ATTR}": "%s" % tool_attr,
            "%{GZIP_ATTR}": "%s" % gzip_attr,
            "%{XZ_ATTR}": "%s" % xz_attr,
        },
        False,
    )

# Repository rule to generate a docker_toolchain target
toolchain_configure = repository_rule(
    attrs = {
        "build_tar_target": attr.label(
            executable = True,
            cfg = "host",
            allow_files = True,
            mandatory = False,
            doc = "The bazel target for the build_tar tool.",
        ),
        "client_config": attr.label(
            mandatory = False,
            doc = "A Bazel label for the docker client config.json. " +
                  "If this is not specified, the value " +
                  "of the DOCKER_CONFIG environment variable will be used. " +
                  "If DOCKER_CONFIG is not defined, the default set for the " +
                  "docker tool (typically, the home directory) will be " +
                  "used.",
        ),
        "cred_helpers": attr.string_list(
            mandatory = False,
            doc = """Labels to a list of credential helpers binaries that are configured in `client_config`.

            More about credential helpers: https://docs.docker.com/engine/reference/commandline/login/#credential-helpers
            """,
            default = [],
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
        "docker_target": attr.string(
            mandatory = False,
            doc = "The bazel target for the docker tool. " +
                  "Can only be set if docker_path is not set.",
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
        "xz_target": attr.label(
            executable = True,
            cfg = "host",
            allow_files = True,
            mandatory = False,
            doc = "The bazel target for the xz tool. " +
                  "Can only be set if xz_path is not set.",
        ),
    },
    environ = [
        "PATH",
    ],
    implementation = _toolchain_configure_impl,
)
