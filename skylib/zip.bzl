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
"""Functions for producing the gzip of an artifact."""

def _gzip_path(toolchain_info):
    """Resolve the user-supplied gzip path, if any.

    Args:
       toolchain_info: The DockerToolchainInfo

    Returns:
       Path to gzip, or empty string.
    """
    if toolchain_info.gzip_target:
        return toolchain_info.gzip_target.files_to_run.executable.path
    else:
        return toolchain_info.gzip_path

def gzip(ctx, artifact, options = None):
    """Create an action to compute the gzipped artifact.

    Args:
       ctx: The context
       artifact: The artifact to zip
       options: str list, Command-line options to pass to gzip.

    Returns:
       the gzipped artifact.
    """
    out = ctx.actions.declare_file(artifact.basename + ".gz")
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    gzip_path = _gzip_path(toolchain_info)

    if gzip_path == "":
        # If the user did not specify a gzip tool, use the Go helper provided with rules_docker.
        ctx.actions.run(
            executable = ctx.executable._zipper,
            arguments = ["-src", artifact.path, "-dst", out.path] + (options or []),
            inputs = [artifact],
            outputs = [out],
            mnemonic = "GZIP",
            tools = ctx.attr._zipper[DefaultInfo].default_runfiles.files,
        )
    else:
        input_manifests = []
        tools = []
        if toolchain_info.gzip_target:
            tools, _, input_manifests = ctx.resolve_command(tools = [toolchain_info.gzip_target])

        opt_str = " ".join([repr(o) for o in (options or [])])
        ctx.actions.run_shell(
            command = "%s -n %s < %s > %s" % (gzip_path, opt_str, artifact.path, out.path),
            input_manifests = input_manifests,
            inputs = [artifact],
            outputs = [out],
            use_default_shell_env = True,
            mnemonic = "GZIP",
            tools = tools,
        )
    return out

def gunzip(ctx, artifact):
    """Create an action to compute the gunzipped artifact.

    Args:
       ctx: The context
       artifact: The artifact to zip

    Returns:
       the gunzipped artifact.
    """
    out = ctx.actions.declare_file(artifact.basename + ".nogz")
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    gzip_path = _gzip_path(toolchain_info)

    if gzip_path == "":
        # If the user did not specify a gzip tool, use the Go helper provided with rules_docker.
        ctx.actions.run(
            executable = ctx.executable._zipper,
            arguments = ["-decompress", "-src", artifact.path, "-dst", out.path],
            inputs = [artifact],
            outputs = [out],
            mnemonic = "GUNZIP",
            tools = ctx.attr._zipper[DefaultInfo].default_runfiles.files,
        )
    else:
        input_manifests = []
        tools = []
        if toolchain_info.gzip_target:
            tools, _, input_manifests = ctx.resolve_command(tools = [toolchain_info.gzip_target])
        ctx.actions.run_shell(
            command = "%s -d < %s > %s" % (gzip_path, artifact.path, out.path),
            input_manifests = input_manifests,
            inputs = [artifact],
            outputs = [out],
            use_default_shell_env = True,
            mnemonic = "GUNZIP",
            tools = tools,
        )
    return out

tools = {
    "_zipper": attr.label(
        default = Label("//container/go/cmd/zipper"),
        cfg = "host",
        executable = True,
    ),
}
