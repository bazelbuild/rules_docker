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

load("@bazel_skylib//lib:dicts.bzl", "dicts")
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
    _zip_tools = "tools",
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
load("//container:providers.bzl", "LayerInfo")

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

        # data path get get calculated incorrectly for external repo
        if data_path.startswith("/.."):
            data_path = data_path[1:]
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
        tars = None,
        operating_system = None):
    """Build the current layer for appending it to the base layer"""
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    layer = output_layer
    build_layer_exec = ctx.executable.build_layer
    args = [
        "--output=" + layer.path,
        "--directory=" + directory,
        "--mode=" + ctx.attr.mode,
    ]

    if toolchain_info.xz_path != "":
        args += ["--xz_path=%s" % toolchain_info.xz_path]

    # Windows layer.tar require two separate root directories instead of just 1
    # 'Files' is the equivalent of '.' in Linux images.
    # 'Hives' is unique to Windows Docker images.  It is where per layer registry
    # changes are stored.  rules_docker doesn't support registry deltas, but the
    # directory is required for compatibility on Windows.
    empty_root_dirs = []
    if (operating_system == "windows"):
        args += ["--root_directory=Files"]
        empty_root_dirs = ["Files", "Hives"]

    all_files = [struct(src = f.path, dst = _magic_path(ctx, f, layer)) for f in files]
    all_files += [struct(src = f.path, dst = path) for (path, f) in file_map.items()]
    manifest = struct(
        files = all_files,
        symlinks = [struct(linkname = k, target = symlinks[k]) for k in symlinks],
        empty_files = empty_files or [],
        empty_dirs = empty_dirs or [],
        empty_root_dirs = empty_root_dirs,
        tars = [f.path for f in tars],
        debs = [f.path for f in debs],
    )
    manifest_file = ctx.actions.declare_file(name + "-layer.manifest")
    ctx.actions.write(manifest_file, manifest.to_json())
    args += ["--manifest=" + manifest_file.path]

    ctx.actions.run(
        executable = build_layer_exec,
        arguments = args,
        tools = files + file_map.values() + tars + debs + [manifest_file],
        outputs = [layer],
        use_default_shell_env = True,
        mnemonic = "ImageLayer",
    )
    return layer, _sha256(ctx, layer)

def zip_layer(ctx, layer):
    zipped_layer = _gzip(ctx, layer)
    return zipped_layer, _sha256(ctx, zipped_layer)

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
        operating_system = None,
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
    operating_system: operating system to target (e.g. linux, windows)
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
    operating_system = operating_system or ctx.attr.operating_system
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
        operating_system = operating_system,
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

_layer_attrs = dicts.add({
    "data_path": attr.string(),
    "directory": attr.string(default = "/"),
    "files": attr.label_list(allow_files = True),
    "mode": attr.string(default = "0o555"),  # 0o555 == a+rx
    "tars": attr.label_list(allow_files = tar_filetype),
    "debs": attr.label_list(allow_files = deb_filetype),
    "symlinks": attr.string_dict(),
    "env": attr.string_dict(),
    # Implicit/Undocumented dependencies.
    "empty_files": attr.string_list(),
    "empty_dirs": attr.string_list(),
    "operating_system": attr.string(
        default = "linux",
        mandatory = False,
    ),
    "build_layer": attr.label(
        default = Label("//container:build_tar"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}, _hash_tools, _layer_tools, _zip_tools)

_layer_outputs = {
    "layer": "%{name}-layer.tar",
}

layer = struct(
    attrs = _layer_attrs,
    outputs = _layer_outputs,
    implementation = _impl,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

container_layer_ = rule(
    attrs = _layer_attrs,
    executable = False,
    outputs = _layer_outputs,
    implementation = _impl,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def container_layer(**kwargs):
    container_layer_(**kwargs)
