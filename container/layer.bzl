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
    "//skylib:hash.bzl",
    _hash_tools = "tools",
    _sha256 = "sha256",
)
load("@io_bazel_rules_docker//container:providers.bzl", "LayerInfo")
load(
    "//container:layer_tools.bzl",
    _layer_tools = "tools",
)
load(
    "//skylib:filetype.bzl",
    deb_filetype = "deb",
    tar_filetype = "tar",
)
load(
    "//skylib:path.bzl",
    "dirname",
    "strip_prefix",
    _canonicalize_path = "canonicalize",
    _join_path = "join",
)
load(
    "//skylib:zip.bzl",
    _gzip = "gzip",
    _zip_tools = "tools",
)

_DOC = "A rule that assembles data into a tarball which can be use as in layers attr in container_image rule."

_DEFAULT_MTIME = -1

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
    """Build the current layer for appending it to the base layer

    Args:
       ctx: The context
       name: The name of the layer
       output_layer: The output location for this layer
       files: Files to include in the layer
       file_map: Map of files to include in layer (source to dest inside layer)
       empty_files: List of empty files in the layer
       empty_dirs: List of empty dirs in the layer
       directory: Directory in which to store the file inside the layer
       symlinks: List of symlinks to include in the layer
       debs: List of debian package tar files
       tars: List of tar files
       operating_system: The OS (e.g., 'linux', 'windows')

    Returns:
       the layer tar and its sha256 digest

    """
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    layer = output_layer
    if toolchain_info.build_tar_target:
        build_layer_exec = toolchain_info.build_tar_target.files_to_run.executable
    else:
        build_layer_exec = ctx.executable.build_layer
    args = ctx.actions.args()
    args.add(layer, format = "--output=%s")
    args.add(directory, format = "--directory=%s")
    args.add(ctx.attr.mode, format = "--mode=%s")

    if ctx.attr.mtime != _DEFAULT_MTIME:  # Note: Must match default in rule def.
        if ctx.attr.portable_mtime:
            fail("You may not set both mtime and portable_mtime")
        args.add(ctx.attr.mtime, format = "--mtime=%s")
    if ctx.attr.portable_mtime:
        args.add("--mtime=portable")
    if ctx.attr.enable_mtime_preservation:
        args.add("--enable_mtime_preservation=true")

    xz_path = toolchain_info.xz_path
    xz_tools = []
    xz_input_manifests = []
    if toolchain_info.xz_target:
        xz_path = toolchain_info.xz_target.files_to_run.executable.path
        xz_tools, _, xz_input_manifests = ctx.resolve_command(tools = [toolchain_info.xz_target])
    elif toolchain_info.xz_path == "":
        print("WARNING: xz could not be found. Make sure it is in the path or set it " +
              "explicitly in the docker_toolchain_configure")
    args.add(xz_path, format = "--xz_path=%s")

    # Windows layer.tar require two separate root directories instead of just 1
    # 'Files' is the equivalent of '.' in Linux images.
    # 'Hives' is unique to Windows Docker images.  It is where per layer registry
    # changes are stored.  rules_docker doesn't support registry deltas, but the
    # directory is required for compatibility on Windows.
    empty_root_dirs = []
    if (operating_system == "windows"):
        args.add("--root_directory=Files")
        empty_root_dirs = ["Files", "Hives"]
    elif build_layer_exec.path.endswith(".exe"):
        # Building on Windows, but not for Windows. Do not use the default root directory.
        args.add("--root_directory=")
        args.add("--force_posixpath=true")

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
    args.add(manifest_file, format = "--manifest=%s")

    ctx.actions.run(
        executable = build_layer_exec,
        arguments = [args],
        input_manifests = xz_input_manifests,
        tools = files + file_map.values() + tars + debs + [manifest_file] + xz_tools,
        outputs = [layer],
        use_default_shell_env = True,
        mnemonic = "ImageLayer",
    )
    return layer, _sha256(ctx, layer)

def zip_layer(ctx, layer, compression = "", compression_options = None):
    """Generate the zipped filesystem layer, and its sha256 (aka blob sum)

    Args:
       ctx: The bazel rule context
       layer: File, layer tar
       compression: str, compression mode, eg "gzip"
       compression_options: str, command-line options for the compression tool

    Returns:
       (zipped layer, blobsum)
    """
    compression_options = compression_options or []
    if compression == "gzip":
        zipped_layer = _gzip(ctx, layer, options = compression_options)
    else:
        fail(
            'Unrecognized compression method (need "gzip"): %r' % compression,
            attr = "compression",
        )

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
        compression = None,
        compression_options = None,
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
    compression: str, overrides ctx.attr.compression
    compression_options: str list, overrides ctx.attr.compression_options
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
    compression = ctx.attr.compression
    compression_options = ctx.attr.compression_options
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
    zipped_layer, blob_sum = zip_layer(
        ctx,
        unzipped_layer,
        compression = compression,
        compression_options = compression_options,
    )

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
    "build_layer": attr.label(
        default = Label("//container:build_tar"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "compression": attr.string(default = "gzip"),
    "compression_options": attr.string_list(),
    "data_path": attr.string(
        doc = """Root path of the files.

        The directory structure from the files is preserved inside the
        Docker image, but a prefix path determined by `data_path`
        is removed from the directory structure. This path can
        be absolute from the workspace root if starting with a `/` or
        relative to the rule's directory. A relative path may starts with "./"
        (or be ".") but cannot use go up with "..". By default, the
        `data_path` attribute is unused, and all files should have no prefix.
        """,
    ),
    "debs": attr.label_list(
        allow_files = deb_filetype,
        doc = """Debian packages to extract.

        Deprecated: A list of debian packages that will be extracted in the Docker image.
        Note that this doesn't actually install the packages. Installation needs apt
        or apt-get which need to be executed within a running container which
        `container_image` can't do.""",
    ),
    "directory": attr.string(
        default = "/",
        doc = """Target directory.

        The directory in which to expand the specified files, defaulting to '/'.
        Only makes sense accompanying one of files/tars/debs.""",
    ),
    "empty_dirs": attr.string_list(),
    # Implicit/Undocumented dependencies.
    "empty_files": attr.string_list(),
    "enable_mtime_preservation": attr.bool(default = False),
    "env": attr.string_dict(
        doc = """Dictionary from environment variable names to their values when running the Docker image.

        See https://docs.docker.com/engine/reference/builder/#env

        For example,

            env = {
                "FOO": "bar",
                ...
            },

        The values of this field support make variables (e.g., `$(FOO)`)
        and stamp variables; keys support make variables as well.""",
    ),
    "files": attr.label_list(
        allow_files = True,
        doc = """File to add to the layer.

        A list of files that should be included in the Docker image.""",
    ),
    "mode": attr.string(
        default = "0o555",  # 0o555 == a+rx
        doc = "Set the mode of files added by the `files` attribute.",
    ),
    "mtime": attr.int(default = _DEFAULT_MTIME),
    "operating_system": attr.string(
        default = "linux",
        mandatory = False,
    ),
    "portable_mtime": attr.bool(default = False),
    "symlinks": attr.string_dict(
        doc = """Symlinks to create in the Docker image.

        For example,

            symlinks = {
                "/path/to/link": "/path/to/target",
                ...
            },
        """,
    ),
    "tars": attr.label_list(
        allow_files = tar_filetype,
        doc = """Tar file to extract in the layer.

        A list of tar files whose content should be in the Docker image.""",
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
    doc = _DOC,
    attrs = layer.attrs,
    executable = False,
    outputs = layer.outputs,
    implementation = layer.implementation,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def container_layer(**kwargs):
    container_layer_(**kwargs)
