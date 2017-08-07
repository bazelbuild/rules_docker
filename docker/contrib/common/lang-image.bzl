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
"""Helpers for synthesizing foo_image targets matching foo_binary.
"""

load(
    "//docker:docker.bzl",
    _docker = "docker",
)
load("//docker:pull.bzl", "docker_pull")

def _dep_layer_impl(ctx):
  """Appends a layer for a single dependency's runfiles."""

  return _docker.build.implementation(
    ctx,
    # We put the files from dependency layers into a binary-agnostic
    # path to increase the likelihood of layer sharing across images,
    # then we symlink them into the appropriate place in the app layer.
    # This references the binary package because the file paths are
    # relative to it, and normalized by the tarball package.
    directory=ctx.attr.directory + "/" + ctx.label.package,
    files=list(ctx.attr.dep.default_runfiles.files),
    empty_files=[
      ctx.attr.directory + "/" + empty
      for empty in ctx.attr.dep.default_runfiles.empty_filenames
    ]
  )

dep_layer = rule(
    attrs = _docker.build.attrs + {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(mandatory = True),

        # Override the defaults.
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
        "directory": attr.string(default = "/app"),
    },
    executable = True,
    outputs = _docker.build.outputs,
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
    ctx.attr.directory,
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
           # It is notable that this assumes that our version of
	   # this runfile matches that of the dependency.  It is
	   # not clear at this time whether that is an invariant
	   # broadly in Bazel.
           if f.short_path not in available]

  empty_files = [
    base_directory + "/" + f
    for f in ctx.attr.binary.default_runfiles.empty_filenames
    if f not in available
  ]

  # For each of the runfiles we aren't including directly into
  # the application layer, link to their binary-agnostic
  # location from the runfiles path.
  symlinks = {
    binary_name: directory + "/" + basename
  } + {
    directory + "/" + input: ctx.attr.directory + "/" + input
    for input in available
  }

  return _docker.build.implementation(
    ctx, files=files, empty_files=empty_files,
    # Use entrypoint so we can easily add arguments when the resulting
    # image is `docker run ...`.
    # Per: https://docs.docker.com/engine/reference/builder/#entrypoint
    # we should use the "exec" (list) form of entrypoint.
    entrypoint=ctx.attr.entrypoint + [binary_name],
    directory=directory, symlinks=symlinks)

app_layer = rule(
    attrs = _docker.build.attrs + {
        # The binary target for which we are synthesizing an image.
        "binary": attr.label(mandatory = True),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "layers": attr.label_list(),
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        "entrypoint": attr.string_list(default = []),

        # Override the defaults.
        "data_path": attr.string(default = "."),
        "workdir": attr.string(default = "/app"),
        "directory": attr.string(default = "/app"),
        "legacy_run_behavior": attr.bool(default = False),
    },
    executable = True,
    outputs = _docker.build.outputs,
    implementation = _app_layer_impl,
)
