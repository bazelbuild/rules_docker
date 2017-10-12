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
"""Rule for importing an image from 'docker save' tarballs.

This extracts the tarball, examines the layers and creates a
container_import target for use with container_image.
"""

def _manifest_layers(manifest):
  # Extracts layers, preserving order, from the manifest.

  layers_begin_marker = "\"Layers\":["
  start = manifest.index(layers_begin_marker)
  end = manifest.index("]", start)

  start += len(layers_begin_marker)
  layers = manifest[start:end].replace("\"", "").split(",")

  if not layers:
    fail("Failed to extract layers from manifest.json")

  return layers

def _gzip_layers(ctx):
  # Returns an array of gzipped layers, preserving order.

  manifest = ctx.execute(["cat", "manifest.json"])
  if manifest.return_code:
    fail("Could not read manifest: %s" % manifest.stderr)

  zipped_layers = []
  layers = _manifest_layers(manifest.stdout)
  for layer in layers:
    zipped_layer = layer.split("/")[0] + ".tar.gz"
    result = ctx.execute(["gzip", "-n", layer])
    if result.return_code:
      fail("Failed to gzip image layer %s: %s" % (layer, result.stderr))
    result = ctx.execute(["mv", layer + ".gz", zipped_layer])
    if result.return_code:
      fail("Failed to gzip image layer %s: %s" % (layer, result.stderr))
    zipped_layers += ["\"" + zipped_layer + "\","]

  return zipped_layers

def _config_json(ctx):
  # Identifies the image config json file in the root directory.

  config_candidates = ctx.execute(["ls", "-1"])
  if config_candidates.return_code:
    fail("Failed to list contents: %s" % config_candidates.stderr)

  config = None
  for candidate in config_candidates.stdout.splitlines():
    if candidate.endswith(".json") and candidate != "manifest.json":
      config = candidate
      break

  if not config:
    fail("Failed to find config file")

  return config

def _container_archive_impl(ctx):
  ctx.download_and_extract(url=ctx.attr.urls,
                           sha256=ctx.attr.sha256,
                           type=ctx.attr.type,
                           stripPrefix=ctx.attr.strip_prefix)

  zipped_layers = _gzip_layers(ctx)

  config = _config_json(ctx)

  ctx.file("BUILD", """
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_docker//container:import.bzl", "container_import")

container_import(
  name = \"""" + ctx.attr.image_tag + """\",
  config = \"""" + config + """\",
  layers = [
    """ + "\n    ".join(zipped_layers) + """
  ],
  repository = \"""" + ctx.attr.image_repository + """\",
)
""", executable=False)
    

container_archive = repository_rule(
    attrs = {
        "urls": attr.string_list(allow_empty = False),
        "sha256": attr.string(),
        "type": attr.string(),
        "strip_prefix": attr.string(),
        "image_repository": attr.string(default = "bazel"),
        "image_tag": attr.string(default = "image"),
    },
    implementation = _container_archive_impl,
)
