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

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "@io_bazel_rules_docker//container:providers.bzl",
    "FilterAspectInfo",
    "FilterLayerInfo",
)
load(
    "//container:container.bzl",
    _container = "container",
)
load(
    "//container:layer_tools.bzl",
    _get_layers = "get_from_target",
)

def _binary_name(ctx):
    # For //foo/bar/baz:blah this would translate to
    # /app/foo/bar/baz/blah
    return "/".join([
        ctx.attr.directory,
        ctx.attr.binary.label.package,
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
    if FilterLayerInfo in dep:
        return dep[FilterLayerInfo].runfiles.files
    else:
        return dep[DefaultInfo].default_runfiles.files

def _default_emptyfiles(dep):
    if FilterLayerInfo in dep:
        return dep[FilterLayerInfo].runfiles.empty_filenames
    else:
        return dep[DefaultInfo].default_runfiles.empty_filenames

def _default_symlinks(dep):
    if FilterLayerInfo in dep:
        return dep[FilterLayerInfo].runfiles.symlinks
    else:
        return dep[DefaultInfo].default_runfiles.symlinks

def _app_layer_impl(ctx, runfiles = None, emptyfiles = None):
    """Appends a layer for a single dependency's runfiles.

    Args:
        ctx: The Bazel runtime context object.
        runfiles: (Optional) depset of runfiles to include in this language
                  image layer.
        emptyfiles: (Optional) depset of empty files to include in this
                    language image layer.

    Returns:
        A container image provider for the application layer.
    """

    runfiles = runfiles or _default_runfiles
    emptyfiles = emptyfiles or _default_emptyfiles
    empty_dirs = []
    workdir = None

    parent_parts = _get_layers(ctx, ctx.attr.name, ctx.attr.base)
    filepath = _final_file_path if ctx.attr.binary else layer_file_path
    emptyfilepath = _final_emptyfile_path if ctx.attr.binary else _layer_emptyfile_path
    dep = ctx.attr.dep or ctx.attr.binary
    top_layer = ctx.attr.binary and not ctx.attr.dep

    if ctx.attr.create_empty_workspace_dir:
        # Create an empty directory for the workspace in the app directory.
        empty_dirs.append("/".join([ctx.attr.directory, ctx.workspace_name]))

    # Compute the set of runfiles that have been made available
    # in our base image, tracking absolute paths.
    available = {
        f: None
        for f in parent_parts.get("transitive_files", depset()).to_list()
    }

    # Compute the set of remaining runfiles to include into the
    # application layer.
    # runfiles(dep) can be `depset` or `list`. Convert it to list only if needed.
    runfiles_list = runfiles(dep).to_list() if type(runfiles(dep)) == "depset" else runfiles(dep)
    file_map = {
        filepath(ctx, f): f
        for f in runfiles_list
        if filepath(ctx, f) not in available and layer_file_path(ctx, f) not in available
    }

    # emptyfiles(dep) can be `depset` or `list`. Convert it to list only if needed.
    emptyfiles_list = emptyfiles(dep).to_list() if type(emptyfiles(dep)) == "depset" else emptyfiles(dep)
    empty_files = [
        emptyfilepath(ctx, f)
        for f in emptyfiles_list
        if emptyfilepath(ctx, f) not in available and _layer_emptyfile_path(ctx, f) not in available
    ]

    symlinks = {}

    # If the caller provided the binary that will eventually form the
    # app layer, we can already create symlinks to the runfiles path.
    if ctx.attr.binary:
        # Include any symlinks from the runfiles of the target for which we are synthesizing the layer.
        symlinks.update({
            (_reference_dir(ctx) + "/" + s.path): layer_file_path(ctx, s.target_file)
            for s in _default_symlinks(dep).to_list()
            if hasattr(s, "path")  # "path" and "target_file" are exposed to starlark since bazel 0.21.0.
        })

        symlinks.update({
            _final_file_path(ctx, f): layer_file_path(ctx, f)
            for f in runfiles_list
            if _final_file_path(ctx, f) not in file_map and _final_file_path(ctx, f) not in available
        })
        symlinks.update({
            _final_emptyfile_path(ctx, f): _layer_emptyfile_path(ctx, f)
            for f in emptyfiles_list
            if _final_emptyfile_path(ctx, f) not in empty_files and _final_emptyfile_path(ctx, f) not in available
        })

    entrypoint = None
    if top_layer:
        entrypoint = ctx.attr.entrypoint + [_binary_name(ctx)]
        workdir = ctx.attr.workdir or "/".join([_runfiles_dir(ctx), ctx.workspace_name])
        symlinks.update({
            # Create a symlink from our entrypoint to where it will actually be put
            # under runfiles.
            _binary_name(ctx): _final_file_path(ctx, ctx.executable.binary),
            # Create a directory symlink from <workspace>/external to the runfiles
            # root, since they may be accessed via either path.
            _external_dir(ctx): _runfiles_dir(ctx),
        })

    # args of the form $(location :some_target) are expanded to the path of the underlying file
    args = [ctx.expand_location(arg, ctx.attr.data) for arg in ctx.attr.args]

    return _container.image.implementation(
        ctx,
        # We use all absolute paths.
        directory = "/",
        file_map = file_map,
        empty_files = empty_files,
        empty_dirs = empty_dirs,
        symlinks = symlinks,
        workdir = workdir,
        # Use entrypoint so we can easily add arguments when the resulting
        # image is `docker run ...`.
        # Per: https://docs.docker.com/engine/reference/builder/#entrypoint
        # we should use the "exec" (list) form of entrypoint.
        entrypoint = entrypoint,
        cmd = args,
        # If `args` is set to [], None or not set, Docker config will have
        # a null `Cmd` value.
        null_cmd = args == [],
    )

image = struct(
    attrs = dicts.add(_container.image.attrs, {
        # The base image on which to overlay the dependency layers.
        "base": attr.label(mandatory = True),
        # The binary target for which we are synthesizing an image.
        # If specified, the layer will not be "image agnostic", meaning
        # that the runfiles required by "dep" will be created (or symlinked,
        # if already found in an agnostic path from the base image) under
        # the runfiles dir.
        "binary": attr.label(
            executable = True,
            cfg = "target",
        ),
        # Set this to true to create an empty workspace directory under the
        # app directory specified as the 'directory' attribute.
        "create_empty_workspace_dir": attr.bool(default = False),
        "data": attr.label_list(allow_files = True),

        # Override the defaults.
        # https://github.com/bazelbuild/bazel/issues/2176
        "data_path": attr.string(default = "."),
        # The dependency whose runfiles we're appending.
        # If not specified, then the layer will be treated as the top layer,
        # and all remaining deps of "binary" will be added under runfiles.
        "dep": attr.label(),
        "directory": attr.string(default = "/app"),
        "entrypoint": attr.string_list(default = []),
        "legacy_run_behavior": attr.bool(default = False),
        "workdir": attr.string(default = ""),
    }),
    outputs = _container.image.outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _app_layer_impl,
)

_app_layer = rule(
    attrs = image.attrs,
    executable = True,
    outputs = image.outputs,
    toolchains = image.toolchains,
    implementation = image.implementation,
)

# Convenience function that instantiates the _app_layer rule and returns
# the name (useful when chaining layers).
def app_layer(name, **kwargs):
    _app_layer(name = name, **kwargs)
    return name

def _filter_aspect_impl(target, ctx):
    if FilterLayerInfo in target:
        # If the aspect propagated along the "deps" attr to another filter layer,
        # then take the filtered depset instead of descending further.
        return [FilterAspectInfo(depset = target[FilterLayerInfo].filtered_depset)]

    # Collect transitive deps from all children (propagating along "deps" attr).
    target_deps = depset(transitive = [dep[FilterAspectInfo].depset for dep in getattr(ctx.rule.attr, "deps", [])])
    myself = struct(target = target, target_deps = target_deps)
    return [
        FilterAspectInfo(
            depset = depset(direct = [myself], transitive = [target_deps]),
        ),
    ]

# Aspect for collecting dependency info.
_filter_aspect = aspect(
    attr_aspects = ["deps"],
    implementation = _filter_aspect_impl,
)

def _filter_layer_rule_impl(ctx):
    transitive_deps = ctx.attr.dep[FilterAspectInfo].depset

    runfiles = ctx.runfiles()
    filtered_depsets = []
    for dep in transitive_deps.to_list():
        if str(dep.target.label).startswith(ctx.attr.filter) and str(dep.target.label) != str(ctx.attr.dep.label):
            runfiles = runfiles.merge(dep.target[DefaultInfo].default_runfiles)
            filtered_depsets.append(dep.target_deps)

    # Forward legacy builtin provider and PyInfo provider
    return [
        FilterLayerInfo(
            runfiles = runfiles,
            filtered_depset = depset(transitive = filtered_depsets),
        ),
    ] + ([ctx.attr.dep[PyInfo]] if PyInfo in ctx.attr.dep else [])

# A rule that allows selecting a subset of transitive dependencies, and using
# them as a layer in an image.
filter_layer = rule(
    attrs = {
        "dep": attr.label(
            aspects = [_filter_aspect],
            mandatory = True,
        ),
        # Include in this layer only transitive dependencies whose label starts with "filter".
        # For example, set filter="@" to include only external dependencies.
        "filter": attr.string(default = ""),
    },
    implementation = _filter_layer_rule_impl,
)
