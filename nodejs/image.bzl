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

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@build_bazel_rules_nodejs//:defs.bzl", "nodejs_binary")
load(
    "//container:container.bzl",
    "container_pull",
)
load(
    "//lang:image.bzl",
    "app_layer",
    lang_image = "image",
)
load(
    "//repositories:repositories.bzl",
    _repositories = "repositories",
)

# Load the resolved digests.
load(":nodejs.bzl", "DIGESTS")

def repositories():
    """Import the dependencies of the nodejs_image rule.

    Call the core "repositories" function to reduce boilerplate. This is
    idempotent if folks call it themselves.
    """
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
    "@io_bazel_rules_docker//:debug": "@nodejs_debug_image_base//image",
    "@io_bazel_rules_docker//:fastbuild": "@nodejs_image_base//image",
    "@io_bazel_rules_docker//:optimized": "@nodejs_image_base//image",
    "//conditions:default": "@nodejs_debug_image_base//image",
})

def _runfiles(dep):
    return depset(transitive = [dep[DefaultInfo].default_runfiles.files, dep[DefaultInfo].data_runfiles.files, dep.files])

def _emptyfiles(dep):
    return depset(transitive = [dep[DefaultInfo].default_runfiles.empty_filenames, dep[DefaultInfo].data_runfiles.empty_filenames])

def _dep_layer_impl(ctx):
    return lang_image.implementation(ctx, runfiles = _runfiles, emptyfiles = _emptyfiles)

_dep_layer = rule(
    attrs = dicts.add(lang_image.attrs, {
        "dep": attr.label(
            mandatory = True,
            allow_files = True,  # override
        ),
    }),
    executable = True,
    outputs = lang_image.outputs,
    toolchains = lang_image.toolchains,
    implementation = _dep_layer_impl,
)

def nodejs_image(
        name,
        base = None,
        data = [],
        layers = [],
        node_modules = "//:node_modules",
        binary = None,
        **kwargs):
    """Constructs a container image wrapping a nodejs_binary target.

  Args:
    name: Name of the nodejs_image target.
    base: Base image to use for the nodejs_image.
    data: Runtime dependencies of the nodejs_image.
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    node_modules: The list of Node modules to include in the nodejs image.
    binary: An alternative binary target to use instead of generating one.
    **kwargs: See nodejs_binary.
  """
    layers = [
        # Put the Node binary into its own layer.
        "@nodejs//:node",
        # node_modules can get large, it should be in its own layer.
        node_modules,
    ] + layers

    if not binary:
        binary = name + ".binary"
        nodejs_binary(
            name = binary,
            node_modules = node_modules,
            data = data + layers,
            **kwargs
        )

    # TODO(mattmoor): Consider making the directory into which the app
    # is placed configurable.
    base = base or DEFAULT_BASE
    for index, dep in enumerate(layers):
        this_name = "%s.%d" % (name, index)
        _dep_layer(name = this_name, base = base, dep = dep, binary = binary, testonly = kwargs.get("testonly"))
        base = this_name

    visibility = kwargs.get("visibility", None)
    tags = kwargs.get("tags", None)
    app_layer(
        name = name,
        base = base,
        binary = binary,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
        data = kwargs.get("data"),
        testonly = kwargs.get("testonly"),
    )
