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
    "//container:container.bzl",
    _container = "container",
)

def _binary_name(ctx):
    # For //foo/bar/baz:blah this would translate to
    # /app/foo/bar/baz/blah
    return "/".join([
        ctx.attr.directory,
        ctx.label.package,
        ctx.attr.binary.label.name,
    ])

def _runfiles_dir(ctx):
    # For @foo//bar/baz:blah this would translate to
    # /app/bar/baz/blah.runfiles
    return _binary_name(ctx) + ".runfiles"

    # The directory relative to which all ".short_path" paths are relative.

def _reference_dir(ctx):
    # For @foo//bar/baz:blah this would translate to
    # /app/bar/baz/blah.runfiles/foo
    return "/".join([_runfiles_dir(ctx), ctx.workspace_name])

    # The special "external" directory which is an alternate way of accessing
    # other repositories.

def _external_dir(ctx):
    # For @foo//bar/baz:blah this would translate to
    # /app/bar/baz/blah.runfiles/foo/external
    return "/".join([_reference_dir(ctx), "external"])

    # The final location that this file needs to exist for the foo_binary target to
    # properly execute.

def _final_emptyfile_path(ctx, name):
    if not name.startswith("external/"):
        # Names that don't start with external are relative to our own workspace.
        return _reference_dir(ctx) + "/" + name

        # References to workspace-external dependencies, which are identifiable
        # because their path begins with external/, are inconsistent with the
        # form of their File counterparts, whose ".short_form" is relative to
        #    .../foo.runfiles/workspace-name/  (aka _reference_dir(ctx))
        # whereas we see:
        #    external/foreign-workspace/...
        # so we "fix" the empty files' paths by removing "external/" and basing them
        # directly on the runfiles path.

    return "/".join([_runfiles_dir(ctx), name[len("external/"):]])

    # The final location that this file needs to exist for the foo_binary target to
    # properly execute.

def _final_file_path(ctx, f):
    return "/".join([_reference_dir(ctx), f.short_path])

    # The foo_binary independent location in which we store a particular dependency's
    # file such that it can be shared.

def _layer_emptyfile_path(ctx, name):
    if not name.startswith("external/"):
        # Names that don't start with external are relative to our own workspace.
        return "/".join([ctx.attr.directory, ctx.workspace_name, name])

        # References to workspace-external dependencies, which are identifiable
        # because their path begins with external/, are inconsistent with the
        # form of their File counterparts, whose ".short_form" is relative to
        #    .../foo.runfiles/workspace-name/  (aka _reference_dir(ctx))
        # whereas we see:
        #    external/foreign-workspace/...
        # so we "fix" the empty files' paths by removing "external/" and basing them
        # directly on the runfiles path.

    return "/".join([ctx.attr.directory, name[len("external/"):]])

    # The foo_binary independent location in which we store a particular dependency's
    # file such that it can be shared.

def layer_file_path(ctx, f):
    return "/".join([ctx.attr.directory, ctx.workspace_name, f.short_path])

def _default_runfiles(dep):
    return dep.default_runfiles.files

def _default_emptyfiles(dep):
    return dep.default_runfiles.empty_filenames

def dep_layer_impl(ctx, runfiles = None, emptyfiles = None):
    """Appends a layer for a single dependency's runfiles."""

    runfiles = runfiles or _default_runfiles
    emptyfiles = emptyfiles or _default_emptyfiles

    filepath = layer_file_path if ctx.attr.agnostic_dep_layout else _final_file_path
    emptyfilepath = _layer_emptyfile_path if ctx.attr.agnostic_dep_layout else _final_emptyfile_path

    return _container.image.implementation(
        ctx,
        # We use all absolute paths.
        directory = "/",
        # We put the files from dependency layers into a binary-agnostic
        # path to increase the likelihood of layer sharing across images,
        # then we symlink them into the appropriate place in the app layer.
        # This references the binary package because the file paths are
        # relative to it, and normalized by the tarball package.
        file_map = {
            filepath(ctx, f): f
            for f in runfiles(ctx.attr.dep)
        },
        empty_files = [
            emptyfilepath(ctx, empty)
            for empty in emptyfiles(ctx.attr.dep)
        ],
    )

dep_layer = rule(
    attrs = dict(_container.image.attrs.items() + {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The dependency whose runfiles we're appending.
        "dep": attr.label(
            mandatory = True,
            allow_files = True,
        ),

        # Whether to lay out each dependency in a manner that is agnostic
        # of the binary in which it is participating.  This can increase
        # sharing of the dependency's layer across images, but requires a
        # symlink forest in the app layers.
        "agnostic_dep_layout": attr.bool(default = True),
        # The binary target for which we are synthesizing an image.
        # This is needed iff agnostic_dep_layout.
        "binary": attr.label(mandatory = False),

        # Override the defaults.
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
        "directory": attr.string(default = "/app"),
    }.items()),
    executable = True,
    outputs = _container.image.outputs,
    implementation = dep_layer_impl,
)

def _app_layer_impl(ctx, runfiles = None, emptyfiles = None):
    """Appends the app layer with all remaining runfiles."""

    runfiles = runfiles or _default_runfiles
    emptyfiles = emptyfiles or _default_emptyfiles

    # Compute the set of runfiles that have been made available
    # in our base image, tracking absolute paths.
    available = {}
    for dep in ctx.attr.lang_layers:
        available.update({
            _final_file_path(ctx, f): layer_file_path(ctx, f)
            for f in runfiles(dep)
        })
        available.update({
            _final_emptyfile_path(ctx, f): _layer_emptyfile_path(ctx, f)
            for f in emptyfiles(dep)
        })

        # Compute the set of remaining runfiles to include into the
        # application layer.

    file_map = {
        _final_file_path(ctx, f): f
        for f in runfiles(ctx.attr.binary)
        if _final_file_path(ctx, f) not in available
    }

    empty_files = [
        _final_emptyfile_path(ctx, f)
        for f in emptyfiles(ctx.attr.binary)
        if _final_emptyfile_path(ctx, f) not in available
    ]

    # For each of the runfiles we aren't including directly into
    # the application layer, link to their binary-agnostic
    # location from the runfiles path.
    symlinks = {}

    # Include symlinks to available files if they were laid out in a
    # binary-agnostic fashion.
    if ctx.attr.agnostic_dep_layout:
        symlinks.update(available)

    symlinks.update({
        # Create a symlink from our entrypoint to where it will actually be put
        # under runfiles.
        _binary_name(ctx): _final_file_path(ctx, ctx.executable.binary),
        # Create a directory symlink from <workspace>/external to the runfiles
        # root, since they may be accessed via either path.
        _external_dir(ctx): _runfiles_dir(ctx),
    })

    return _container.image.implementation(
        ctx,
        # We use all absolute paths.
        directory = "/",
        file_map = file_map,
        empty_files = empty_files,
        symlinks = symlinks,
        # Use entrypoint so we can easily add arguments when the resulting
        # image is `docker run ...`.
        # Per: https://docs.docker.com/engine/reference/builder/#entrypoint
        # we should use the "exec" (list) form of entrypoint.
        entrypoint = ctx.attr.entrypoint + [_binary_name(ctx)] + ctx.attr.args,
    )

app_layer = rule(
    attrs = dict(_container.image.attrs.items() + {
        # The binary target for which we are synthesizing an image.
        "binary": attr.label(
            mandatory = True,
            executable = True,
            cfg = "target",
        ),
        # The full list of dependencies that have their own layers
        # factored into our base.
        "lang_layers": attr.label_list(allow_files = True),
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        "entrypoint": attr.string_list(default = []),

        # Whether each dependency is laid out in a manner that is agnostic
        # of the binary in which it is participating.  This can increase
        # sharing of the dependency's layer across images, but requires a
        # symlink forest in the app layers.
        "agnostic_dep_layout": attr.bool(default = True),

        # Override the defaults.
        "data_path": attr.string(default = "."),
        "workdir": attr.string(default = "/app"),
        "directory": attr.string(default = "/app"),
        "legacy_run_behavior": attr.bool(default = False),
    }.items()),
    executable = True,
    outputs = _container.image.outputs,
    implementation = _app_layer_impl,
)
