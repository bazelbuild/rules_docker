# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""A rule for creating a Node.js container image.

The signature of this rule is compatible with nodejs_binary.
"""

load(
    "//lang:image.bzl",
    "dep_layer_impl",
    "dep_layer_attrs",
    "app_layer_impl",
    "app_layer_attrs",
)
load(
    "//container:container.bzl",
    "container_pull",
    _container = "container",
    _repositories = "repositories",
)

# Load the resolved digests.
load(":nodejs.bzl", "DIGESTS")

def repositories():
  # Call the core "repositories" function to reduce boilerplate.
  # This is idempotent if folks call it themselves.
  _repositories()

  excludes = native.existing_rules().keys()
  if "nodejs_image_base" not in excludes:
    container_pull(
      name = "nodejs_image_base",
      registry = "gcr.io",
      repository = "google-appengine/debian9",
      digest = DIGESTS["latest"],
    )
  if "nodejs_debug_image_base" not in excludes:
    container_pull(
      name = "nodejs_debug_image_base",
      registry = "gcr.io",
      repository = "google-appengine/debian9",
      digest = DIGESTS["debug"],
    )

DEFAULT_BASE = select({
    "@io_bazel_rules_docker//:fastbuild": "@nodejs_image_base//image",
    "@io_bazel_rules_docker//:debug": "@nodejs_debug_image_base//image",
    "@io_bazel_rules_docker//:optimized": "@nodejs_image_base//image",
    "//conditions:default": "@nodejs_debug_image_base//image",
})

def _runfiles(dep):
  return dep.default_runfiles.files + dep.data_runfiles.files + dep.files

def _emptyfiles(dep):
  return dep.default_runfiles.empty_filenames + dep.data_runfiles.empty_filenames

def _dep_layer_impl(ctx):
  return dep_layer_impl(ctx, runfiles=_runfiles, emptyfiles=_emptyfiles)

_dep_layer = rule(
    attrs = dep_layer_attrs,
    executable = True,
    outputs = _container.image.outputs,
    implementation = _dep_layer_impl,
)

def _app_layer_impl(ctx):
  return app_layer_impl(ctx, runfiles=_runfiles, emptyfiles=_emptyfiles)

_app_layer = rule(
    attrs = app_layer_attrs,
    executable = True,
    outputs = _container.image.outputs,
    implementation = _app_layer_impl,
)

load("@build_bazel_rules_nodejs//:defs.bzl", "nodejs_binary")

def nodejs_image(name, base=None, data=[], layers=[],
                 node_modules="//:node_modules", **kwargs):
  """Constructs a container image wrapping a nodejs_binary target.

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See nodejs_binary.
  """
  binary_name = name + ".binary"

  layers = [
    # Put the Node binary into its own layer.
    "@nodejs//:bin/node",
    # node_modules can get large, it should be in its own layer.
    node_modules,
  ] + layers

  nodejs_binary(name=binary_name, node_modules=node_modules,
                data=data + layers, **kwargs)

  # TODO(mattmoor): Consider making the directory into which the app
  # is placed configurable.
  base = base or DEFAULT_BASE
  for index, dep in enumerate(layers):
    this_name = "%s.%d" % (name, index)
    _dep_layer(name=this_name, base=base, dep=dep, binary=binary_name,
               agnostic_dep_layout=False)
    base = this_name

  visibility = kwargs.get('visibility', None)
  tags = kwargs.get('tags', None)
  _app_layer(name=name, base=base, entrypoint=['sh', '-c'],
             # Node.JS hates symlinks.
             agnostic_dep_layout=False,
             binary=binary_name, lang_layers=layers, visibility=visibility,
             tags=tags)
