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
"""Rule for bundling Container images into a tarball."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@io_bazel_rules_docker//container:providers.bzl", "BundleInfo", "STAMP_ATTR", "StampSettingInfo")
load(
    "//container:layer_tools.bzl",
    _assemble_image = "assemble",
    _get_layers = "get_from_target",
    _incr_load = "incremental_load",
    _layer_tools = "tools",
)
load(
    "//skylib:label.bzl",
    _string_to_label = "string_to_label",
)

_DOC = """A rule that aliases and saves N images into a single `docker save` tarball.

This can be consumed in 2 different ways:

  - The output tarball could be used for `docker load` to load all images to docker daemon.

  - The emitted BundleInfo provider could be consumed by contrib/push-all.bzl rules to
    create an executable target which tag and push multiple images to a container registry.
"""

def _container_bundle_impl(ctx):
    """Implementation for the container_bundle rule."""

    # Compute the set of layers from the image_targets.
    image_target_dict = _string_to_label(
        ctx.attr.image_targets,
        ctx.attr.image_target_strings,
    )

    images = {}
    runfiles = []
    stamp = ctx.attr.stamp[StampSettingInfo].value
    for unresolved_tag in ctx.attr.images:
        # Allow users to put make variables into the tag name.
        tag = ctx.expand_make_variables("images", unresolved_tag, {})

        target = ctx.attr.images[unresolved_tag]

        layer = _get_layers(ctx, ctx.label.name, image_target_dict[target])
        images[tag] = layer
        runfiles.append(layer.get("config"))
        runfiles.append(layer.get("config_digest"))
        runfiles += layer.get("unzipped_layer", [])
        runfiles += layer.get("diff_id", [])
        if layer.get("legacy"):
            runfiles.append(layer.get("legacy"))

    _incr_load(
        ctx,
        images,
        ctx.outputs.executable,
        stamp = stamp,
    )
    _assemble_image(
        ctx,
        images,
        ctx.outputs.tar_output,
        ctx.attr.experimental_tarball_format,
        stamp = stamp,
    )

    stamp_files = [ctx.info_file, ctx.version_file] if stamp else []

    return [
        BundleInfo(
            container_images = images,
            stamp = stamp,
        ),
        DefaultInfo(
            executable = ctx.outputs.executable,
            files = depset(),
            runfiles = ctx.runfiles(files = (stamp_files + runfiles)),
        ),
        OutputGroupInfo(
            tar = depset([ctx.outputs.tar_output]),
        ),
    ]

container_bundle_ = rule(
    doc = _DOC,
    attrs = dicts.add({
        "image_target_strings": attr.string_list(),
        # Implicit dependencies.
        "image_targets": attr.label_list(allow_files = True),
        "images": attr.string_dict(),
        "stamp": STAMP_ATTR,
        "tar_output": attr.output(),
        "experimental_tarball_format": attr.string(
            values = [
                "legacy",
                "compressed",
            ],
            default = "legacy",
            doc = ("The tarball format to use when producing an image .tar file. " +
                   "Defaults to \"legacy\", which contains uncompressed layers. " +
                   "If set to \"compressed\", the resulting tarball will contain " +
                   "compressed layers, but is only loadable by newer versions of " +
                   "docker. This is an experimental attribute, which is subject " +
                   "to change or removal: do not depend on its exact behavior."),
        ),
    }, _layer_tools),
    executable = True,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _container_bundle_impl,
)

# Produces a new container image tarball compatible with 'docker load', which
# contains the N listed 'images', each aliased with their key.
#
# Example:
#   container_bundle(
#     name = "foo",
#     images = {
#       "ubuntu:latest": ":blah",
#       "foo.io/bar:canary": "//baz:asdf",
#     }
#   )
def container_bundle(**kwargs):
    """Package several container images into a single tarball.

  Args:
    **kwargs: See above.
  """
    for reserved in ["image_targets", "image_target_strings"]:
        if reserved in kwargs:
            fail("reserved for internal use by container_bundle macro", attr = reserved)

    if "images" in kwargs:
        values = {value: None for value in kwargs["images"].values()}.keys()
        kwargs["image_targets"] = values
        kwargs["image_target_strings"] = values

    name = kwargs["name"]
    tar_output = kwargs.pop("tar_output", name + ".tar")
    kwargs["tar_output"] = tar_output
    container_bundle_(**kwargs)
