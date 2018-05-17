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
"""Rule for building a Container layer."""

load(
    "//skylib:filetype.bzl",
    container_filetype = "container",
    deb_filetype = "deb",
    tar_filetype = "tar",
)
load(
    "@bazel_tools//tools/build_defs/hash:hash.bzl",
    _hash_tools = "tools",
    _sha256 = "sha256",
)
load(
    "//skylib:zip.bzl",
    _gzip = "gzip",
)
load(
    "//container:layer_tools.bzl",
    _layer_tools = "tools",
)
load(
    "//skylib:path.bzl",
    "dirname",
    "strip_prefix",
    _canonicalize_path = "canonicalize",
    _join_path = "join",
)

def _magic_path(ctx, f, output_layer):
    # Right now the logic this uses is a bit crazy/buggy, so to support
    # bug-for-bug compatibility in the foo_image rules, expose the logic.
    # See also: https://github.com/bazelbuild/rules_docker/issues/106
    # See also: https://groups.google.com/forum/#!topic/bazel-discuss/1lX3aiTZX3Y

    if ctx.attr.data_path:
        # If data_prefix is specified, then add files relative to that.
        data_path = _join_path(
            dirname(output_layer.short_path),
            _canonicalize_path(ctx.attr.data_path),
        )
        return strip_prefix(f.short_path, data_path)
    else:
        # Otherwise, files are added without a directory prefix at all.
        return f.basename

def build_layer(
        ctx,
        name,
        output_layer,
        files = None,
        file_map = None,
        empty_files = None,
        empty_dirs = None,
        directory = None,
        symlinks = None,
        debs = None,
        tars = None):
    """Build the current layer for appending it to the base layer"""
    layer = output_layer
    build_layer_exec = ctx.executable.build_layer
    args = [
        "--output=" + layer.path,
        "--directory=" + directory,
        "--mode=" + ctx.attr.mode,
    ]

    args += ["--file=%s=%s" % (f.path, _magic_path(ctx, f, layer)) for f in files]
    args += ["--file=%s=%s" % (f.path, path) for (path, f) in file_map.items()]
    args += ["--empty_file=%s" % f for f in empty_files or []]
    args += ["--empty_dir=%s" % f for f in empty_dirs or []]
    args += ["--tar=" + f.path for f in tars]
    args += ["--deb=" + f.path for f in debs]
    for k in symlinks:
        if ":" in k:
            fail("The source of a symlink cannot container ':', got: %s" % k)
    args += ["--link=%s:%s" % (k, symlinks[k]) for k in symlinks]
    arg_file = ctx.new_file(name + "-layer.args")
    ctx.file_action(arg_file, "\n".join(args))
    ctx.action(
        executable = build_layer_exec,
        arguments = ["--flagfile=" + arg_file.path],
        inputs = files + file_map.values() + tars + debs + [arg_file],
        outputs = [layer],
        use_default_shell_env = True,
        mnemonic = "ImageLayer",
    )
    return layer, _sha256(ctx, layer)

def zip_layer(ctx, layer):
    zipped_layer = _gzip(ctx, layer)
    return zipped_layer, _sha256(ctx, zipped_layer)

# A provider containing information needed in container_image and other rules.

LayerInfo = provider(fields = [
    "zipped_layer",
    "blob_sum",
    "unzipped_layer",
    "diff_id",
    "env",
])

def _impl(
        ctx,
        name = None,
        files = None,
        file_map = None,
        empty_files = None,
        empty_dirs = None,
        directory = None,
        symlinks = None,
        debs = None,
        tars = None,
        env = None,
        output_layer = None):
    """Implementation for the container_layer rule.

  Args:
    ctx: The bazel rule context
    name: str, overrides ctx.label.name or ctx.attr.name
    files: File list, overrides ctx.files.files
    file_map: Dict[str, File], defaults to {}
    empty_files: str list, overrides ctx.attr.empty_files
    empty_dirs: Dict[str, str], overrides ctx.attr.empty_dirs
    directory: str, overrides ctx.attr.directory
    symlinks: str Dict, overrides ctx.attr.symlinks
    env: str Dict, overrides ctx.attr.env
    debs: File list, overrides ctx.files.debs
    tars: File list, overrides ctx.files.tars
    output_layer: File, overrides ctx.outputs.layer
  """
    name = name or ctx.label.name
    file_map = file_map or {}
    files = files or ctx.files.files
    empty_files = empty_files or ctx.attr.empty_files
    empty_dirs = empty_dirs or ctx.attr.empty_dirs
    directory = directory or ctx.attr.directory
    symlinks = symlinks or ctx.attr.symlinks
    debs = debs or ctx.files.debs
    tars = tars or ctx.files.tars
    output_layer = output_layer or ctx.outputs.layer

    # Generate the unzipped filesystem layer, and its sha256 (aka diff_id)
    unzipped_layer, diff_id = build_layer(
        ctx,
        name = name,
        output_layer = output_layer,
        files = files,
        file_map = file_map,
        empty_files = empty_files,
        empty_dirs = empty_dirs,
        directory = directory,
        symlinks = symlinks,
        debs = debs,
        tars = tars,
    )

    # Generate the zipped filesystem layer, and its sha256 (aka blob sum)
    zipped_layer, blob_sum = zip_layer(ctx, unzipped_layer)

    # Returns constituent parts of the Container layer as provider:
    # - in container_image rule, we need to use all the following information,
    #   e.g. zipped_layer etc., to assemble the complete container image.
    # - in order to expose information from container_layer rule to container_image
    #   rule, they need to be packaged into a provider, see:
    #   https://docs.bazel.build/versions/master/skylark/rules.html#providers
    return [LayerInfo(
        zipped_layer = zipped_layer,
        blob_sum = blob_sum,
        unzipped_layer = unzipped_layer,
        diff_id = diff_id,
        env = env or ctx.attr.env,
    )]

_layer_attrs = dict({
    "data_path": attr.string(),
    "directory": attr.string(default = "/"),
    "files": attr.label_list(allow_files = True),
    "mode": attr.string(default = "0555"),  # 0555 == a+rx
    "tars": attr.label_list(allow_files = tar_filetype),
    "debs": attr.label_list(allow_files = deb_filetype),
    "symlinks": attr.string_dict(),
    "env": attr.string_dict(),
    # Implicit/Undocumented dependencies.
    "empty_files": attr.string_list(),
    "empty_dirs": attr.string_list(),
    "build_layer": attr.label(
        default = Label("//container:build_tar"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}.items() + _hash_tools.items() + _layer_tools.items())

_layer_outputs = {
    "layer": "%{name}-layer.tar",
}

layer = struct(
    attrs = _layer_attrs,
    outputs = _layer_outputs,
    implementation = _impl,
)

container_layer_ = rule(
    attrs = _layer_attrs,
    executable = False,
    outputs = _layer_outputs,
    implementation = _impl,
)

def container_layer(**kwargs):
    container_layer_(**kwargs)
