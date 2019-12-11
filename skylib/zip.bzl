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
load(
    ":actions.bzl",
    _execution_requirements = "execution_requirements",
)

def gzip(ctx, artifact):
    """Create an action to compute the gzipped artifact.

    Args:
       ctx: The context
       artifact: The artifact to zip

    Returns:
       the gzipped artifact.
    """
    out = ctx.actions.declare_file(artifact.basename + ".gz")
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    input_manifests = []
    tools = []
    gzip_path = toolchain_info.gzip_path
    if toolchain_info.gzip_target:
        gzip_path = toolchain_info.gzip_target.files_to_run.executable.path
        tools, _, input_manifests = ctx.resolve_command(tools = [toolchain_info.gzip_target])
    elif toolchain_info.gzip_path == "":
        fail("gzip could not be found. Make sure it is in the path or set it " +
             "explicitly in the docker_toolchain_configure")

    ctx.actions.run_shell(
        command = "%s -n < %s > %s" % (gzip_path, artifact.path, out.path),
        input_manifests = input_manifests,
        inputs = [artifact],
        outputs = [out],
        use_default_shell_env = True,
        mnemonic = "GZIP",
        execution_requirements = _execution_requirements(ctx.attr.tags),
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
    input_manifests = []
    tools = []
    gzip_path = toolchain_info.gzip_path
    if toolchain_info.gzip_target:
        gzip_path = toolchain_info.gzip_target.files_to_run.executable.path
        tools, _, input_manifests = ctx.resolve_command(tools = [toolchain_info.gzip_target])
    elif toolchain_info.gzip_path == "":
        fail("gzip could not be found. Make sure it is in the path or set it " +
             "explicitly in the docker_toolchain_configure")
    ctx.actions.run_shell(
        command = "%s -d < %s > %s" % (gzip_path, artifact.path, out.path),
        input_manifests = input_manifests,
        inputs = [artifact],
        outputs = [out],
        use_default_shell_env = True,
        mnemonic = "GUNZIP",
        execution_requirements = _execution_requirements(ctx.attr.tags),
        tools = tools,
    )
    return out
