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

load(
    "//skylib:label.bzl",
    _string_to_label = "string_to_label",
)
load(
    "//container:layer_tools.bzl",
    _assemble_image = "assemble",
    _get_layers = "get_from_target",
    _incr_load = "incremental_load",
    _layer_tools = "tools",
)
load("//container:providers.bzl", "BundleInfo")

def _container_bundle_impl(ctx):
    """Implementation for the container_bundle rule."""

    # Compute the set of layers from the image_targets.
    image_target_dict = _string_to_label(
        ctx.attr.image_targets,
        ctx.attr.image_target_strings,
    )

    images = {}
    runfiles = []
    for unresolved_tag in ctx.attr.images:
        # Allow users to put make variables into the tag name.
        tag = ctx.expand_make_variables("images", unresolved_tag, {})

        target = ctx.attr.images[unresolved_tag]

        l = _get_layers(ctx, ctx.label.name, image_target_dict[target])
        images[tag] = l
        runfiles += [l.get("config")]
        runfiles += [l.get("config_digest")]
        runfiles += l.get("unzipped_layer", [])
        runfiles += l.get("diff_id", [])

    _incr_load(
        ctx,
        images,
        ctx.outputs.executable,
        stamp = ctx.attr.stamp,
    )
    _assemble_image(ctx, images, ctx.outputs.out, stamp = ctx.attr.stamp)

    stamp_files = []
    if ctx.attr.stamp:
        stamp_files = [ctx.info_file, ctx.version_file]

    return struct(
        container_images = images,
        stamp = ctx.attr.stamp,
        providers = [
            BundleInfo(
                container_images = images,
                stamp = ctx.attr.stamp,
            ),
            DefaultInfo(
                files = depset(),
                executable = ctx.outputs.executable,
                runfiles = ctx.runfiles(files = (stamp_files + runfiles)),
            ),
        ],
    )

container_bundle_ = rule(
    attrs = dict({
        "images": attr.string_dict(),
        # Implicit dependencies.
        "image_targets": attr.label_list(allow_files = True),
        "image_target_strings": attr.string_list(),
        "stamp": attr.bool(
            default = False,
            mandatory = False,
        ),
    }.items() + _layer_tools.items()),
    executable = True,
    outputs = {
        "out": "%{name}.tar",
    },
    toolchains = ["//tools:toolchain_type_docker"],
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

    container_bundle_(**kwargs)
