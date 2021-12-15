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
load("@build_bazel_rules_nodejs//:index.bzl", "nodejs_binary")
load("@build_bazel_rules_nodejs//:providers.bzl", "NodeRuntimeDepsInfo", "NpmPackageInfo")
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
    "//repositories:go_repositories.bzl",
    _go_deps = "go_deps",
)

# Load the resolved digests.
load(":nodejs.bzl", "DIGESTS")

def repositories():
    """Import the dependencies of the nodejs_image rule.

    Call the core "go_deps" function to reduce boilerplate. This is
    idempotent if folks call it themselves.
    """
    _go_deps()

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

def _npm_deps_runfiles(dep):
    """
    Collects the npm package sources of all the transitive deps of the dep
    """
    depsets = []
    for pkg in dep[NodeRuntimeDepsInfo].pkgs:
        if NpmPackageInfo in pkg:
            depsets.append(pkg[NpmPackageInfo].sources)
    return depset(transitive = depsets)

def _npm_deps_layer_impl(ctx):
    return lang_image.implementation(ctx, runfiles = _npm_deps_runfiles, emptyfiles = _emptyfiles)

_npm_deps_layer = rule(
    attrs = lang_image.attrs,
    executable = True,
    outputs = lang_image.outputs,
    toolchains = lang_image.toolchains,
    implementation = _npm_deps_layer_impl,
)

def nodejs_image(
        name,
        base = None,
        data = [],
        layers = [],
        binary = None,
        launcher = None,
        launcher_args = None,
        node_repository_name = "nodejs",
        include_node_repo_args = True,
        **kwargs):
    """Constructs a container image wrapping a nodejs_binary target.

  Args:
    name: Name of the nodejs_image target.
    base: Base image to use for the nodejs_image.
    data: Runtime dependencies of the nodejs_image.
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    binary: An alternative binary target to use instead of generating one.
    launcher: The container_image launcher to set.
    launcher_args: The args for the container_image launcher.
    **kwargs: See nodejs_binary.
  """

    if not binary:
        binary = name + ".binary"
        nodejs_binary(
            name = binary,
            data = data + layers,
            **kwargs
        )

    nodejs_layers = [
        # Put the Node binary into its own layers.
        "@%s//:node" % node_repository_name,
        "@%s//:node_files" % node_repository_name,
    ]

    if include_node_repo_args:
        nodejs_layers.append("@%s//:bin/node_repo_args.sh" % node_repository_name)

    all_layers = nodejs_layers + layers

    visibility = kwargs.get("visibility", None)
    tags = kwargs.get("tags", None)

    # TODO(mattmoor): Consider making the directory into which the app
    # is placed configurable.
    base = base or DEFAULT_BASE
    for index, dep in enumerate(all_layers):
        this_name = "%s.%d" % (name, index)
        _dep_layer(name = this_name, base = base, dep = dep, binary = binary, testonly = kwargs.get("testonly"), visibility = visibility, tags = tags)
        base = this_name

    npm_deps_layer_name = "%s.npm_deps" % name
    _npm_deps_layer(name = npm_deps_layer_name, base = base, binary = binary, testonly = kwargs.get("testonly"), visibility = visibility, tags = tags)

    app_layer(
        name = name,
        base = npm_deps_layer_name,
        binary = binary,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
        data = data,
        testonly = kwargs.get("testonly"),
        launcher = launcher,
        launcher_args = launcher_args,
    )
