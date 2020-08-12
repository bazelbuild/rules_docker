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
"""Rule for building a Container image from an existing Container image
by excluding some files and directories.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "@bazel_tools//tools/build_defs/hash:hash.bzl",
    _hash_tools = "tools",
    _sha256 = "sha256",
)
load(
    "@io_bazel_rules_docker//container:providers.bzl",
    "LayerInfo",
)
load(
    "//container:layer.bzl",
    _zip_layer = "zip_layer",
)

def build_layer(
        ctx,
        name,
        layer,
        output_layer,
        remove_paths = None,
        operating_system = None):
    """Build the current layer by copying an existing layer and excluding the specified files and directories

    Args:
       ctx: The context
       name: The name of the layer
       layer: The container_layer to copy from.
       output_layer: The output location for this layer
       remove_paths: A list of case-sensitive glob patterns to exclude from this layer.
         Removing a directory removes all its contents recursively.
       operating_system: The OS (e.g., 'linux', 'windows')

    Returns:
       the new layer tar and its sha256 digest

    """
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    build_layer_exec = ctx.executable.build_layer
    args = ctx.actions.args()
    args.add(output_layer, format = "--output=%s")

    # Windows layer.tar require two separate root directories instead of just 1
    # 'Files' is the equivalent of '.' in Linux images.
    # 'Hives' is unique to Windows Docker images.  It is where per layer registry
    # changes are stored.  rules_docker doesn't support registry deltas, but the
    # directory is required for compatibility on Windows.
    if (operating_system == "windows"):
        args.add("--root_directory=Files")

    manifest = struct(
        remove_paths = remove_paths or [],
        unzipped_layer = layer[LayerInfo].unzipped_layer.path,
    )
    manifest_file = ctx.actions.declare_file(name + "-layer.manifest")
    ctx.actions.write(manifest_file, manifest.to_json())
    args.add(manifest_file, format = "--manifest=%s")

    ctx.actions.run(
        executable = build_layer_exec,
        arguments = [args],
        tools = [layer[LayerInfo].unzipped_layer, manifest_file],
        outputs = [output_layer],
        use_default_shell_env = True,
        mnemonic = "ImageLayer",
    )

    return output_layer, _sha256(ctx, output_layer)

def _impl(
        ctx,
        name = None,
        layer = None,
        remove_paths = None,
        compression = None,
        compression_options = None,
        operating_system = None,
        output_layer = None):
    """Implementation for the container_layer_prune rule.

    Args:
        ctx: The bazel rule context
        name: str, overrides ctx.label.name or ctx.attr.name
        layer: label, overrides ctx.attr.layer
        remove_paths: str List, overrides ctx.attr.remove_paths
        compression: str, overrides ctx.attr.compression
        compression_options: str list, overrides ctx.attr.compression_options
        operating_system: operating system to target (e.g. linux, windows)
        output_layer: File, overrides ctx.outputs.layer
    """
    name = name or ctx.label.name
    layer = layer or ctx.attr.layer
    remove_paths = remove_paths or ctx.attr.remove_paths
    compression = compression or ctx.attr.compression
    compression_options = compression_options or ctx.attr.compression_options
    operating_system = operating_system or ctx.attr.operating_system
    output_layer = output_layer or ctx.outputs.layer

    # Generate the unzipped filesystem layer, and its sha256 (aka diff_id)
    unzipped_layer, diff_id = build_layer(
        ctx,
        name = name,
        layer = layer,
        output_layer = output_layer,
        remove_paths = remove_paths,
        operating_system = operating_system,
    )

    # Generate the zipped filesystem layer, and its sha256 (aka blob sum)
    zipped_layer, blob_sum = _zip_layer(
        ctx,
        unzipped_layer,
        compression = compression,
        compression_options = compression_options,
    )

    # Returns constituent parts of the Container layer as provider:
    # - in container_image rule, we need to use all the following information,
    #   e.g. zipped_layer etc., to assemble the complete container image.
    # - in order to expose information from container_layer rule to container_image
    #   rule, they need to be packaged into a provider, see:
    #   https://docs.bazel.build/versions/master/skylark/rules.html#providers
    return [LayerInfo(
        zipped_layer = zipped_layer,
        blob_sum = blob_sum,
        unzipped_layer = unzipped_layer,
        diff_id = diff_id,
        env = layer[LayerInfo].env,
    )]

_layer_attrs = dicts.add({
    "build_layer": attr.label(
        default = Label("//container:prune_tar"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "compression": attr.string(default = "gzip"),
    "compression_options": attr.string_list(),
    "layer": attr.label(providers = [LayerInfo]),
    "operating_system": attr.string(
        default = "linux",
        mandatory = False,
        values = ["linux", "windows"],
    ),
    "remove_paths": attr.string_list(),
}, _hash_tools)

_layer_outputs = {
    "layer": "%{name}-layer.tar",
}

container_layer_prune_ = rule(
    attrs = _layer_attrs,
    executable = False,
    outputs = _layer_outputs,
    implementation = _impl,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def container_layer_prune(**kwargs):
    container_layer_prune_(**kwargs)
