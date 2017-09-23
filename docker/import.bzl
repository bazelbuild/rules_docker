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
"""Rule for building a Docker image."""

load(
    ":filetype.bzl",
    tgz_filetype = "tgz",
)
load(
    "@bazel_tools//tools/build_defs/hash:hash.bzl",
    _hash_tools = "tools",
    _sha256 = "sha256",
)
load(
    ":zip.bzl",
    _gunzip = "gunzip",
)
load(
    ":layers.bzl",
    _assemble_image = "assemble",
    _incr_load = "incremental_load",
    _layer_tools = "tools",
)
load(
    ":path.bzl",
    "dirname",
    "strip_prefix",
    _canonicalize_path = "canonicalize",
    _join_path = "join",
)

def _unzip_layer(ctx, zipped_layer):
  unzipped_layer = _gunzip(ctx, zipped_layer)
  return unzipped_layer, _sha256(ctx, unzipped_layer)

def _repository_name(ctx):
  """Compute the repository name for the current rule."""
  return _join_path(ctx.attr.repository, ctx.label.package)

def _docker_import_impl(ctx):
  """Implementation for the docker_import rule."""

  blobsums = []
  unzipped_layers = []
  diff_ids = []
  for layer in ctx.files.layers:
    blobsums += [_sha256(ctx, layer)]
    unzipped, diff_id = _unzip_layer(ctx, layer)
    unzipped_layers += [unzipped]
    diff_ids += [diff_id]

  # These are the constituent parts of the Docker image, which each
  # rule in the chain must preserve.
  docker_parts = {
      # The path to the v2.2 configuration file.
      "config": ctx.files.config[0],
      "config_digest": _sha256(ctx, ctx.files.config[0]),

      # A list of paths to the layer .tar.gz files
      "zipped_layer": ctx.files.layers,
      # A list of paths to the layer digests.
      "blobsum": blobsums,

      # A list of paths to the layer .tar files
      "unzipped_layer": unzipped_layers,
      # A list of paths to the layer diff_ids.
      "diff_id": diff_ids,

      # We do not have a "legacy" field, because we are importing a
      # more efficient form.
  }

  # We support incrementally loading or assembling this single image
  # with a temporary name given by its build rule.
  images = {
      _repository_name(ctx) + ":" + ctx.label.name: docker_parts
  }

  _incr_load(ctx, images, ctx.outputs.executable)
  _assemble_image(ctx, images, ctx.outputs.out)

  runfiles = ctx.runfiles(
      files = (docker_parts["unzipped_layer"] +
               docker_parts["diff_id"] +
               [docker_parts["config"],
                docker_parts["config_digest"]]))
  return struct(runfiles = runfiles,
                files = depset([ctx.outputs.out]),
                docker_parts = docker_parts)

docker_import_ = rule(
    attrs = {
        "config": attr.label(allow_files = [".json"]),
        "layers": attr.label_list(allow_files = tgz_filetype),
        "repository": attr.string(default = "bazel"),
    } + _hash_tools + _layer_tools,
    executable = True,
    outputs = {
        "out": "%{name}.tar",
    },
    implementation = _docker_import_impl,
)

def docker_import(**kwargs):
  """Imports a Docker image into our model's intermediate form."""
  docker_import_(**kwargs)
