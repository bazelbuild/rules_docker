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

def _gzip(ctx, artifact, out, decompress, options, mnemonic):
    """A helper that calls either the compiled zipper, or the gzip tool.

    Args:
       ctx: The context
       artifact: The artifact to zip/unzip
       out: The output file.
       decompress: Whether to decompress (True) or compress (False)
       options: str list, Command-line options.
       mnemonic: A one-word description of the action
    """
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    gzip_path = _gzip_path(toolchain_info)

    if not gzip_path:
        # The user did not specify a gzip tool; use the Go helper provided with rules_docker.
        ctx.actions.run(
            executable = ctx.executable._zipper,
            arguments = ["-src", artifact.path, "-dst", out.path] + (
                ["-decompress"] if decompress else []
            ) + (options or []),
            inputs = [artifact],
            outputs = [out],
            mnemonic = mnemonic,
            tools = ctx.attr._zipper[DefaultInfo].default_runfiles.files,
        )
    else:
        # Call the gzip path or target supplied by the user.
        input_manifests = []
        tools = []
        if toolchain_info.gzip_target:
            tools, _, input_manifests = ctx.resolve_command(tools = [toolchain_info.gzip_target])

        opt_str = " ".join([repr(o) for o in (options or [])])
        command = "%s -d %s < %s > %s" if decompress else "%s -n %s < %s > %s"
        command = command % (gzip_path, opt_str, artifact.path, out.path)

        ctx.actions.run_shell(
            command = command,
            input_manifests = input_manifests,
            inputs = [artifact],
            outputs = [out],
            use_default_shell_env = True,
            mnemonic = mnemonic,
            tools = tools,
        )

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
    _gzip(
        ctx = ctx,
        artifact = artifact,
        out = out,
        decompress = False,
        options = options,
        mnemonic = "GZIP",
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
    _gzip(
        ctx = ctx,
        artifact = artifact,
        out = out,
        decompress = True,
        options = None,
        mnemonic = "GUNZIP",
    )
    return out

tools = {
    "_zipper": attr.label(
        default = Label("//container/go/cmd/zipper"),
        cfg = "host",
        executable = True,
    ),
}
