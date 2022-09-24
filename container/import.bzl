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
"""Rule for importing a container image."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "//skylib:hash.bzl",
    _hash_tools = "tools",
    _sha256 = "sha256",
)
load("@io_bazel_rules_docker//container:providers.bzl", "ImportInfo", "PullInfo")
load(
    "//container:layer_tools.bzl",
    _assemble_image = "assemble",
    _incr_load = "incremental_load",
    _layer_tools = "tools",
)
load(
    "//skylib:filetype.bzl",
    tar_filetype = "tar",
    tgz_filetype = "tgz",
)
load(
    "//skylib:path.bzl",
    _join_path = "join",
)
load(
    "//skylib:zip.bzl",
    _gunzip = "gunzip",
    _gzip = "gzip",
    _zip_tools = "tools",
)

def _is_filetype(filename, extensions):
    for filetype in extensions:
        if filename.endswith(filetype):
            return True
    return False

def _is_tgz(layer):
    return _is_filetype(layer.basename, tgz_filetype)

def _is_tar(layer):
    return _is_filetype(layer.basename, tar_filetype)

def _layer_pair(ctx, layer):
    zipped = _is_tgz(layer)
    unzipped = not zipped and _is_tar(layer)
    if not (zipped or unzipped):
        fail("Unknown filetype provided (need .tar or .tar.gz): %s" % layer)

    zipped_layer = layer if zipped else _gzip(ctx, layer)
    unzipped_layer = layer if unzipped else _gunzip(ctx, layer)
    return zipped_layer, unzipped_layer

def _repository_name(ctx):
    """Compute the repository name for the current rule."""
    return _join_path(ctx.attr.repository, ctx.label.package)

def _container_import_impl(ctx):
    """Implementation for the container_import rule."""

    blobsums = []
    zipped_layers = []
    unzipped_layers = []
    diff_ids = []
    for layer in ctx.files.layers:
        zipped, unzipped = _layer_pair(ctx, layer)
        zipped_layers.append(zipped)
        unzipped_layers.append(unzipped)
        blobsums.append(_sha256(ctx, zipped))
        diff_ids.append(_sha256(ctx, unzipped))

    manifest = None
    manifest_digest = None

    if (len(ctx.files.manifest) > 0):
        manifest = ctx.files.manifest[0]
        manifest_digest = _sha256(ctx, ctx.files.manifest[0])

    # These are the constituent parts of the Container image, which each
    # rule in the chain must preserve.

    container_parts = {
        # A list of paths to the layer digests.
        "blobsum": blobsums,
        # The path to the v2.2 configuration file.
        "config": ctx.files.config[0],
        "config_digest": _sha256(ctx, ctx.files.config[0]),
        # A list of paths to the layer diff_ids.
        "diff_id": diff_ids,

        # The path to the optional v2.2 manifest file.
        "manifest": manifest,
        "manifest_digest": manifest_digest,

        # A list of paths to the layer .tar files
        "unzipped_layer": unzipped_layers,

        # A list of paths to the layer .tar.gz files
        "zipped_layer": zipped_layers,

        # We do not have a "legacy" field, because we are importing a
        # more efficient form.
    }

    # We support incrementally loading or assembling this single image
    # with a temporary name given by its build rule.
    images = {
        _repository_name(ctx) + ":" + ctx.label.name: container_parts,
    }

    _incr_load(ctx, images, ctx.outputs.executable)
    _assemble_image(
        ctx,
        images,
        ctx.outputs.out,
        # Experiment: currently only support experimental_tarball_format in
        # container_image for testing optimization.
        # TODO(#1695): Update this.
        "legacy",
    )

    runfiles = ctx.runfiles(
        files = (container_parts["unzipped_layer"] +
                 container_parts["diff_id"] +
                 [
                     container_parts["config"],
                     container_parts["config_digest"],
                 ]),
    )
    if (len(ctx.files.manifest) > 0):
        runfiles = runfiles.merge(
            ctx.runfiles(
                files = ([
                    container_parts["manifest"],
                    container_parts["manifest_digest"],
                ]),
            ),
        )
    pull_info = []
    if (ctx.attr.base_image_registry and ctx.attr.base_image_repository and ctx.attr.base_image_digest):
        pull_info = [
            PullInfo(
                base_image_registry = ctx.attr.base_image_registry,
                base_image_repository = ctx.attr.base_image_repository,
                base_image_digest = ctx.attr.base_image_digest,
            ),
        ]
    return [
        ImportInfo(
            container_parts = container_parts,
        ),
        DefaultInfo(
            executable = ctx.outputs.executable,
            files = depset([ctx.outputs.out]),
            runfiles = runfiles,
        ),
    ] + pull_info

container_import = rule(
    doc = "A rule that imports a docker image into our intermediate form.",
    attrs = dicts.add({
        "base_image_digest": attr.string(doc = "The digest of the image"),
        "base_image_registry": attr.string(doc = "The registry from which we pulled the image"),
        "base_image_repository": attr.string(doc = "The repository from which we pulled the image"),
        "config": attr.label(
            doc = """A json configuration file containing the image's metadata.

            This appears in `docker save` tarballs as `.json` and is referenced by `manifest.json` in the config field.
            """,
            allow_files = [".json"],
        ),
        "layers": attr.label_list(
            doc = """The list of layer .tar.gz files in the order they appear in the config.json's layer section,
            or in the order that they appear in the `Layers` field of the docker save tarballs'
            `manifest.json` (these may or may not be gzipped).
            
            Note that the layers should each have a different basename.
            """,
            allow_files = tar_filetype + tgz_filetype,
            mandatory = True,
        ),
        "manifest": attr.label(
            allow_files = [".json"],
            mandatory = False,
        ),
        "repository": attr.string(default = "bazel"),
    }, _hash_tools, _layer_tools, _zip_tools),
    executable = True,
    outputs = {
        "out": "%{name}.tar",
    },
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _container_import_impl,
)
