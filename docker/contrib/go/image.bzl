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
"""A rule for creating a Go Docker image.

The signature of this rule is compatible with go_binary.
"""

load(
    "//docker:build.bzl",
    _build_attrs = "attrs",
    _build_implementation = "implementation",
    _build_outputs = "outputs",
)
load("//docker:pull.bzl", "docker_pull")

# It is expected that the Go rules have been properly
# initialized before loading this file to initialize
# go_image.
load("@io_bazel_rules_go//go:def.bzl", "go_binary")

# TODO(mattmoor): If we can share this stuff with the other
# languages, then factor out a helper.
def _dep_layer_impl(ctx):
  """Appends a layer for a single dependency's runfiles."""

  return _build_implementation(
    ctx,
    # We put the files from dependency layers into a binary-agnostic
    # path to increase the likelihood of layer sharing across images,
    # then we symlink them into the appropriate place in the app layer.
    # This references the binary package because the file paths are
    # relative to it, and normalized by the tarball package.
    directory="/app/" + ctx.label.package,
    files=list(ctx.attr.dep.default_runfiles.files),
    symlinks={
      # Handle empty files by linking to /dev/null
      "/app/" + empty: "/dev/null"
      for empty in ctx.attr.dep.default_runfiles.empty_filenames
    }
  )

_dep_layer = rule(
    attrs = _build_attrs + {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(default = Label("@go_image_base//image")),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(mandatory = True),

        # Override the defaults.
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
        "directory": attr.string(default = "/app"),
    },
    executable = True,
    outputs = _build_outputs,
    implementation = _dep_layer_impl,
)

def _app_layer_impl(ctx):
  """Appends the app layer with all remaining runfiles."""

  # Compute the set of runfiles that have been made available
  # in our base image.
  available = set()
  for dep in ctx.attr.layers:
    available += [f.short_path for f in dep.default_runfiles.files]
    available += [f for f in dep.default_runfiles.empty_filenames]

  # The name of the binary target for which we are populating
  # this application layer.
  basename = ctx.attr.binary.label.name
  binary_name = "/".join([
    "/app",
    ctx.label.package,
    basename
  ])

  # Empty filenames are relative to this base.
  base_directory = "/".join([
    binary_name + ".runfiles",
    ctx.workspace_name,
  ])
  # All of the files are included with paths relative to
  # this directory.
  directory = "/".join([base_directory, ctx.label.package])

  # Compute the set of remaining runfiles to include into the
  # application layer.
  files = [f for f in ctx.attr.binary.default_runfiles.files
           if f.short_path not in available]

  empty_files = [f for f in ctx.attr.binary.default_runfiles.empty_filenames
                 if f not in available]

  # For each of the runfiles we aren't including directly into
  # the application layer, link to their binary-agnostic
  # location from the runfiles path.
  symlinks = {
    binary_name: directory + "/" + basename
  } + {
    directory + "/" + input: "/app/" + input
    for input in available
  } + {
    # Handle empty files by linking to /dev/null
    base_directory + "/" + empty: "/dev/null"
    for empty in empty_files
  }

  return _build_implementation(
    ctx, files=files,
    # Use entrypoint so we can easily add arguments when the resulting
    # image is `docker run ...`.
    # Per: https://docs.docker.com/engine/reference/builder/#entrypoint
    # we should use the "exec" (list) form of entrypoint.
    entrypoint=[binary_name],
    directory=directory, symlinks=symlinks)

_app_layer = rule(
    attrs = _build_attrs + {
        # The go_binary target for which we are synthesizing an image.
        "binary": attr.label(mandatory = True),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "layers": attr.label_list(),
        # The base image on which to overlay the dependency layers.
        "base": attr.label(default = Label("@go_image_base//image")),

        # Override the defaults.
        "data_path": attr.string(default = "."),
        "workdir": attr.string(default = "/app"),
    },
    executable = True,
    outputs = _build_outputs,
    implementation = _app_layer_impl,
)

def repositories():
  excludes = native.existing_rules().keys()
  if "go_image_base" not in excludes:
    docker_pull(
      name = "go_image_base",
      registry = "gcr.io",
      repository = "distroless/base",
      # 'latest' circa 2017-07-21
      digest = "sha256:06fcd3edcfeefe13b82fa8bdb9e3f4fa3bf4c7e8fe997bee0230e392f77d0e04",
    )

def go_image(name, deps=[], layers=[], **kwargs):
  """Constructs a Docker image wrapping a go_binary target.

  Args:
    layers: Augments "deps" with dependencies that should be put into their own layers.
    **kwargs: See go_binary.
  """
  binary_name = name + ".binary"

  go_binary(name=binary_name, deps=deps + layers, **kwargs)

  index = 0
  base = None # Makes us use ctx.attr.base
  for dep in layers:
    this_name = "%s.%d" % (name, index)
    _dep_layer(name=this_name, base=base, dep=dep)
    base = this_name
    index += 1

  _app_layer(name=name, base=base, binary=binary_name, layers=layers)
