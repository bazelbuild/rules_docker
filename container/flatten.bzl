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
"""A rule to flatten container images."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@io_bazel_rules_docker//container:providers.bzl", "FlattenInfo")
load(
    "//container:layer_tools.bzl",
    _gen_img_args = "generate_args_for_image",
    _get_layers = "get_from_target",
    _layer_tools = "tools",
)

def _impl(ctx):
    """Core implementation of container_flatten."""

    image = _get_layers(ctx, ctx.label.name, ctx.attr.image)

    # Leverage our efficient intermediate representation to push.
    img_args = ctx.actions.args()
    img_inputs = []
    if ctx.attr.use_legacy_flattener:
        if image.get("legacy"):
            img_inputs += [image["legacy"]]
            img_args.add(image["legacy"], format = "--tarball=%s")

        blobsums = image.get("blobsum", [])
        img_args.add_all(blobsums, format_each = "--digest=%s")
        img_inputs += blobsums
        blobs = image.get("zipped_layer", [])
        img_args.add_all(blobs, format_each = "--layer=%s")
        img_inputs += blobs
        uncompressed_blobs = image.get("unzipped_layer", [])
        img_args.add_all(uncompressed_blobs, format_each = "--uncompressed_layer=%s")
        img_inputs += uncompressed_blobs
        diff_ids = image.get("diff_id", [])
        img_args.add_all(diff_ids, format_each = "--diff_id=%s")
        img_inputs += diff_ids
        img_args.add(image["config"], format = "--config=%s")
        img_inputs += [image["config"]]
    else:
        args, img_inputs = _gen_img_args(ctx, image)
        img_args.add_all(args)

    img_args.add(ctx.outputs.filesystem, format = "--filesystem=%s")
    img_args.add(ctx.outputs.metadata, format = "--metadata=%s")
    ctx.actions.run(
        executable = ctx.executable._flattener if ctx.attr.use_legacy_flattener else ctx.executable._go_flattener,
        arguments = [img_args],
        inputs = img_inputs,
        outputs = [ctx.outputs.filesystem, ctx.outputs.metadata],
        use_default_shell_env = True,
        mnemonic = "Flatten",
    )

    return [FlattenInfo()]

container_flatten = rule(
    attrs = dicts.add({
        "image": attr.label(
            allow_single_file = [".tar"],
            mandatory = True,
        ),
        # TODO (smukherj1): Remove once migration in #580 is done.
        "use_legacy_flattener": attr.bool(
            default = True,
            doc = "Use the legacy python flattener to generate the image " +
                  "filesystem tarball. Uses the experimental Go implementation" +
                  "when set to false.",
        ),
        "_flattener": attr.label(
            default = Label("@containerregistry//:flatten"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
        "_go_flattener": attr.label(
            default = Label("//container/go/cmd/flattener"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    }, _layer_tools),
    outputs = {
        "filesystem": "%{name}.tar",
        "metadata": "%{name}.json",
    },
    implementation = _impl,
)
