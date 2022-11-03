# Copyright 2022 The Bazel Authors. All rights reserved.
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
Rules to run a command inside a container, and either commit the result
to new container image, or extract specified targets to a directory on
the host machine.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_tools//tools/build_defs/hash:hash.bzl", _hash_tools = "tools")
load("@io_bazel_rules_docker//container:container.bzl", "container_flatten", "container_layer", "container_image")
load("@io_bazel_rules_docker//container:layer.bzl", "zip_layer")
load("@io_bazel_rules_docker//container:providers.bzl", "ImageInfo", "LayerInfo")
load("@io_bazel_rules_docker//skylib:docker.bzl", "docker_path")
load("@io_bazel_rules_docker//skylib:zip.bzl", _zip_tools = "tools")

TOOLCHAIN_TYPE="@io_bazel_rules_docker//toolchains/docker:toolchain_type"
TOOLCHAINS = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"]
_common_attrs = dict(
    image = attr.label(
        providers = [ImageInfo],
        executable = True,
        cfg = "target",
    ),
    image_config = attr.label(
        allow_single_file = [".json"],
    ),
    commands = attr.string_list(
        doc = "A list of commands to run (sequentially) in the container.",
        mandatory = True,
        allow_empty = False,
    ),
    docker_run_flags = attr.string_list(
        doc = "Extra flags to pass to the docker run command.",
        mandatory = False,
    ),
    _binary = attr.label(
        default = "@io_bazel_rules_docker//docker/util:run",
        cfg = "exec",
        executable = True,
    ),
)

def _extract_impl(ctx, **kwargs):
    arguments = []
    arguments.append("--extract-path={}".format(ctx.attr.extract_file))
    _run(ctx, "RunAndExtract", arguments, ctx.outputs.file, [], **kwargs)

extract_parts = struct(
    attrs = dicts.add(
        _common_attrs,
        dict(
            extract_file = attr.string(
                doc = "Path to file to extract from container.",
                mandatory = True,
            ),
        ),
    ),
    implementation = _extract_impl,
    outputs = dict(file = "%{name}%{extract_file}"),
    toolchains = TOOLCHAINS,
)

def _run(ctx, mnemonic, arguments, main_output, extra_outputs, commands = None, docker_run_flags = None):
    if commands == None:
        commands = ctx.attr.commands

    if docker_run_flags == None:
        docker_run_flags = ctx.attr.docker_run_flags

    digest_file = ctx.attr.image[ImageInfo].container_parts["config_digest"]
    toolchain_info = ctx.toolchains[TOOLCHAIN_TYPE].info
    tool_inputs, tool_input_mfs = ctx.resolve_tools(tools = [ctx.attr.image, ctx.attr._binary])
    output_log = ctx.actions.declare_file(ctx.label.name + ".log")

    docker_run_flags = " ".join([shell.quote(flag) for flag in docker_run_flags])
    arguments.extend([
        "--docker-run-flags={}".format(docker_run_flags),
        "--image-config={}".format(ctx.file.image_config.path),
        "--logfile={}".format(output_log.path),
        ctx.executable.image.path,
        digest_file.path,
        docker_path(toolchain_info),
        " ".join(toolchain_info.docker_flags),
        main_output.path,
    ])
    arguments.extend(commands)

    ctx.actions.run(
        outputs = [main_output, output_log] + extra_outputs,
        inputs = [digest_file, ctx.file.image_config],
        executable = ctx.executable._binary,
        arguments = arguments,
        tools = tool_inputs,
        input_manifests = tool_input_mfs,
        mnemonic = mnemonic,
    )

def _commit_layer_impl(ctx, extract_args = None, **kwargs):
    if extract_args == None:
        extract_args = ctx.attr.extract_args

    output_diff_id = ctx.actions.declare_file(ctx.outputs.layer.basename + ".sha256")

    arguments = []
    for key, value in extract_args.items():
        arguments.append("--{}={}".format(key, value))

    arguments.append("--output-diffid-path={}".format(output_diff_id.path))

    _run(ctx, "RunAndCommitLayer", arguments, ctx.outputs.layer, [output_diff_id], **kwargs)

    zipped_layer, blob_sum = zip_layer(
        ctx,
        ctx.outputs.layer,
        compression = "gzip",
        compression_options = None,
    )
    return [
        LayerInfo(
            unzipped_layer = ctx.outputs.layer,
            diff_id = output_diff_id,
            zipped_layer = zipped_layer,
            blob_sum = blob_sum,
            env = {},
        ),
    ]

commit_layer_parts = struct(
    attrs = dicts.add(
        _common_attrs,
        _zip_tools,
        _hash_tools,
        dict(extract_args = attr.string_dict()),
    ),
    implementation = _commit_layer_impl,
    outputs = dict(layer = "%{name}-layer.tar"),
    toolchains = TOOLCHAINS,
)

_commit_layer = rule(**structs.to_dict(commit_layer_parts))
_extract = rule(**structs.to_dict(extract_parts))

def _update_kwargs(name, *, image, **kwargs):
    return dict(
        name = name,
        image = image,
        image_config = image + ".json",
        **kwargs
    )

def container_run_and_commit_layer(name, **kwargs):
    updated = _update_kwargs(name, **kwargs)
    return _commit_layer(**updated)

def container_run_and_commit(name, *, image, **kwargs):
    container_run_and_commit_layer(
        name + ".run",
        image = image,
        **kwargs
    )

    wrapped_kwargs = dict()
    if "tags" in kwargs:
        wrapped_kwargs["tags"] = kwargs["tags"]

    container_image(
        name = name,
        base = image,
        layers = [":{}.run".format(name)],
        **wrapped_kwargs,
    )


def container_run_and_extract(name, **kwargs):
    updated = _update_kwargs(name, **kwargs)
    return _extract(**updated)
