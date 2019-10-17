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
"""Rule for building a Container image.

In addition to the base container_image rule, we expose its constituents
(attr, outputs, implementation) directly so that others may expose a
more specialized build leveraging the same implementation.  The
expectation in such cases is that users will write something like:

  load(
    "@io_bazel_rules_docker//container:container.bzl",
    _container="container",
  )

  def _impl(ctx):
    ...
    return _container.image.implementation(ctx, ... kwarg overrides ...)

  _foo_image = rule(
      attrs = _container.image.attrs + {
         # My attributes, or overrides of _container.image.attrs defaults.
         ...
      },
      executable = True,
      outputs = _container.image.outputs,
      implementation = _impl,
  )

"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "@bazel_tools//tools/build_defs/hash:hash.bzl",
    _hash_tools = "tools",
    _sha256 = "sha256",
)
load(
    "@io_bazel_rules_docker//container:providers.bzl",
    "ImageInfo",
    "LayerInfo",
)
load(
    "//container:layer.bzl",
    _layer = "layer",
)
load(
    "//container:layer_tools.bzl",
    _assemble_image = "assemble",
    _gen_img_args = "generate_args_for_image",
    _get_layers = "get_from_target",
    _incr_load = "incremental_load",
    _layer_tools = "tools",
)
load(
    "//skylib:filetype.bzl",
    container_filetype = "container",
)
load(
    "//skylib:label.bzl",
    _string_to_label = "string_to_label",
)
load(
    "//skylib:path.bzl",
    _join_path = "join",
)
load(
    "//skylib:zip.bzl",
    _zip_tools = "tools",
)

def _get_base_config(ctx, name, base):
    if ctx.files.base or base:
        # The base is the first layer in container_parts if provided.
        layer = _get_layers(ctx, name, ctx.attr.base, base)
        return layer.get("config")
    return None

def _get_base_manifest(ctx, name, base):
    if ctx.files.base or base:
        # The base is the first layer in container_parts if provided.
        layer = _get_layers(ctx, name, ctx.attr.base, base)
        return layer.get("manifest")
    return None

def _add_create_image_config_args(
        ctx,
        args,
        inputs,
        manifest,
        config,
        labels,
        entrypoint,
        cmd,
        null_cmd,
        null_entrypoint,
        creation_time,
        env,
        workdir,
        layer_names,
        base_config,
        base_manifest,
        operating_system):
    """
    Add args for the create_image_config Go binary.
    """
    args.add("-outputConfig", config)
    args.add("-outputManifest", manifest)

    if null_entrypoint:
        args.add("-nullEntryPoint")

    if null_cmd:
        args.add("-nullCmd")

    args.add_all(entrypoint, before_each = "-entrypoint")
    args.add_all(cmd, before_each = "-command")
    args.add_all(ctx.attr.ports, before_each = "-ports")
    args.add_all(ctx.attr.volumes, before_each = "-volumes")

    if creation_time:
        args.add("-creationTime", creation_time)
    elif ctx.attr.stamp:
        # If stamping is enabled, and the creation_time is not manually defined,
        # default to '{BUILD_TIMESTAMP}'.
        args.add("-creationTime", "{BUILD_TIMESTAMP}")

    for key, value in labels.items():
        args.add("-labels", "{}={}".format(key, value))

    for key, value in env.items():
        args.add("-env", "%s" % "=".join([
            ctx.expand_make_variables("env", key, {}),
            ctx.expand_make_variables("env", value, {}),
        ]))

    if ctx.attr.user:
        args.add("-user", ctx.attr.user)
    if workdir:
        args.add("-workdir", workdir)

    inputs += layer_names
    args.add_all(layer_names, before_each = "-layerDigestFile", format_each = "@%s")

    if ctx.attr.label_files:
        inputs += ctx.files.label_files

    if base_config:
        args.add("-baseConfig", base_config)
        inputs += [base_config]

    if base_manifest:
        args.add("-baseManifest", base_manifest)
        inputs += [base_manifest]

    if operating_system:
        args.add("-operatingSystem", operating_system)

    if ctx.attr.stamp:
        stamp_inputs = [ctx.info_file, ctx.version_file]
        args.add_all(stamp_inputs, before_each = "-stampInfoFile")
        inputs += stamp_inputs

    if ctx.attr.launcher_args and not ctx.attr.launcher:
        fail("launcher_args does nothing when launcher is not specified.", attr = "launcher_args")
    if ctx.attr.launcher:
        args.add("-entrypointPrefix", ctx.file.launcher.basename, format = "/%s")
        args.add_all(ctx.attr.launcher_args)

def _format_legacy_label(t):
    return ("--labels=%s=%s" % (t[0], t[1]))

def _image_config(
        ctx,
        name,
        layer_names,
        entrypoint = None,
        cmd = None,
        creation_time = None,
        env = None,
        base_config = None,
        base_manifest = None,
        operating_system = None,
        layer_name = None,
        workdir = None,
        null_entrypoint = False,
        null_cmd = False):
    """Create the configuration for a new container image."""
    config = ctx.actions.declare_file(name + "." + layer_name + ".config")
    manifest = ctx.actions.declare_file(name + "." + layer_name + ".manifest")

    label_file_dict = _string_to_label(
        ctx.files.label_files,
        ctx.attr.label_file_strings,
    )

    labels = dict()
    for label in ctx.attr.labels:
        fname = ctx.attr.labels[label]
        if fname[0] == "@":
            labels[label] = "@" + label_file_dict[fname[1:]].path
        else:
            labels[label] = fname

    args = ctx.actions.args()
    inputs = []
    executable = None
    _add_create_image_config_args(
        ctx,
        args,
        inputs,
        manifest,
        config,
        labels,
        entrypoint,
        cmd,
        null_cmd,
        null_entrypoint,
        creation_time,
        env,
        workdir,
        layer_names,
        base_config,
        base_manifest,
        operating_system,
    )

    ctx.actions.run(
        executable = ctx.executable.create_image_config,
        arguments = [args],
        inputs = inputs,
        outputs = [config, manifest],
        use_default_shell_env = True,
        mnemonic = "ImageConfig",
    )

    return config, _sha256(ctx, config), manifest, _sha256(ctx, manifest)

def _repository_name(ctx):
    """Compute the repository name for the current rule."""
    if ctx.attr.legacy_repository_naming:
        # Legacy behavior, off by default.
        return _join_path(ctx.attr.repository, ctx.label.package.replace("/", "_"))

    # Newer Docker clients support multi-level names, which are a part of
    # the v2 registry specification.

    return _join_path(ctx.attr.repository, ctx.label.package)

def _assemble_image_digest(ctx, name, image, image_tarball, output_digest):
    img_args, inputs = _gen_img_args(ctx, image)
    args = ctx.actions.args()
    args.add_all(img_args)
    args.add("--dst", output_digest)
    args.add("--format=Docker")

    ctx.actions.run(
        outputs = [output_digest],
        inputs = inputs,
        tools = ([image["legacy"]] if image.get("legacy") else []),
        executable = ctx.executable._digester,
        arguments = [args],
        mnemonic = "ImageDigest",
        progress_message = "Extracting image digest of %s" % image_tarball.short_path,
    )

def _impl(
        ctx,
        name = None,
        base = None,
        files = None,
        file_map = None,
        empty_files = None,
        empty_dirs = None,
        directory = None,
        entrypoint = None,
        cmd = None,
        creation_time = None,
        symlinks = None,
        env = None,
        layers = None,
        debs = None,
        tars = None,
        operating_system = None,
        output_executable = None,
        output_tarball = None,
        output_config = None,
        output_digest = None,
        output_layer = None,
        workdir = None,
        null_cmd = None,
        null_entrypoint = None):
    """Implementation for the container_image rule.

  Args:
    ctx: The bazel rule context
    name: str, overrides ctx.label.name or ctx.attr.name
    base: File, overrides ctx.attr.base and ctx.files.base[0]
    files: File list, overrides ctx.files.files
    file_map: Dict[str, File], defaults to {}
    empty_files: str list, overrides ctx.attr.empty_files
    empty_dirs: Dict[str, str], overrides ctx.attr.empty_dirs
    directory: str, overrides ctx.attr.directory
    entrypoint: str List, overrides ctx.attr.entrypoint
    cmd: str List, overrides ctx.attr.cmd
    creation_time: str, overrides ctx.attr.creation_time
    symlinks: str Dict, overrides ctx.attr.symlinks
    env: str Dict, overrides ctx.attr.env
    layers: label List, overrides ctx.attr.layers
    debs: File list, overrides ctx.files.debs
    tars: File list, overrides ctx.files.tars
    operating_system: Operating system to target (e.g. linux, windows)
    output_executable: File to use as output for script to load docker image
    output_tarball: File, overrides ctx.outputs.out
    output_config: File, overrides ctx.outputs.config
    output_digest: File, overrides ctx.outputs.digest
    output_layer: File, overrides ctx.outputs.layer
    workdir: str, overrides ctx.attr.workdir
    null_cmd: bool, overrides ctx.attr.null_cmd
    null_entrypoint: bool, overrides ctx.attr.null_entrypoint
  """
    name = name or ctx.label.name
    entrypoint = entrypoint or ctx.attr.entrypoint
    cmd = cmd or ctx.attr.cmd
    operating_system = operating_system or ctx.attr.operating_system
    creation_time = creation_time or ctx.attr.creation_time
    output_executable = output_executable or ctx.outputs.executable
    output_tarball = output_tarball or ctx.outputs.out
    output_digest = output_digest or ctx.outputs.digest
    output_config = output_config or ctx.outputs.config
    output_layer = output_layer or ctx.outputs.layer
    null_cmd = null_cmd or ctx.attr.null_cmd
    null_entrypoint = null_entrypoint or ctx.attr.null_entrypoint

    # If this target specifies docker_run_flags, they are always used.
    # Fall back to the base image's run flags if present, otherwise use the default value.
    #
    # We do not use the default argument of attrs.string() in order to distinguish between
    # an image using the default and an image intentionally overriding the base's run flags.
    # Since this is a string attribute, the default value is the empty string.
    if ctx.attr.docker_run_flags != "":
        docker_run_flags = ctx.attr.docker_run_flags
    elif ctx.attr.base and ImageInfo in ctx.attr.base:
        docker_run_flags = ctx.attr.base[ImageInfo].docker_run_flags
    else:
        # Run the container using host networking, so that the service is
        # available to the developer without having to poke around with
        # docker inspect.
        docker_run_flags = "-i --rm --network=host"

    if ctx.attr.launcher:
        if not file_map:
            file_map = {}
        file_map["/" + ctx.file.launcher.basename] = ctx.file.launcher

    # composite a layer from the container_image rule attrs,
    image_layer = _layer.implementation(
        ctx = ctx,
        name = name,
        files = files,
        file_map = file_map,
        empty_files = empty_files,
        empty_dirs = empty_dirs,
        directory = directory,
        symlinks = symlinks,
        debs = debs,
        tars = tars,
        env = env,
        operating_system = operating_system,
        output_layer = output_layer,
    )

    layer_providers = layers or ctx.attr.layers
    layers = [provider[LayerInfo] for provider in layer_providers] + image_layer

    # Get the layers and shas from our base.
    # These are ordered as they'd appear in the v2.2 config,
    # so they grow at the end.
    parent_parts = _get_layers(ctx, name, ctx.attr.base, base)
    zipped_layers = parent_parts.get("zipped_layer", []) + [layer.zipped_layer for layer in layers]
    shas = parent_parts.get("blobsum", []) + [layer.blob_sum for layer in layers]
    unzipped_layers = parent_parts.get("unzipped_layer", []) + [layer.unzipped_layer for layer in layers]
    layer_diff_ids = [layer.diff_id for layer in layers]
    diff_ids = parent_parts.get("diff_id", []) + layer_diff_ids
    new_files = [f for f in file_map or []]
    new_emptyfiles = empty_files or []
    new_symlinks = [f for f in symlinks or []]
    parent_transitive_files = parent_parts.get("transitive_files", depset())
    transitive_files = depset(new_files + new_emptyfiles + new_symlinks, transitive = [parent_transitive_files])

    # Get the config for the base layer
    config_file = _get_base_config(ctx, name, base)
    config_digest = None

    # Get the manifest for the base layer
    manifest_file = _get_base_manifest(ctx, name, base)
    manifest_digest = None

    # Generate the new config layer by layer, using the attributes specified and the diff_id
    for i, layer in enumerate(layers):
        config_file, config_digest, manifest_file, manifest_digest = _image_config(
            ctx,
            name = name,
            layer_names = [layer_diff_ids[i]],
            entrypoint = entrypoint,
            cmd = cmd,
            creation_time = creation_time,
            env = layer.env,
            base_config = config_file,
            base_manifest = manifest_file,
            operating_system = operating_system,
            layer_name = str(i),
            workdir = workdir or ctx.attr.workdir,
            null_entrypoint = null_entrypoint,
            null_cmd = null_cmd,
        )

    # Construct a temporary name based on the build target.
    tag_name = "{}:{}".format(_repository_name(ctx), name)

    # These are the constituent parts of the Container image, which each
    # rule in the chain must preserve.
    container_parts = {
        # A list of paths to the layer digests.
        "blobsum": shas,
        # The path to the v2.2 configuration file.
        "config": config_file,
        "config_digest": config_digest,
        # A list of paths to the layer diff_ids.
        "diff_id": diff_ids,

        # The File containing digest of the image.
        "digest": output_digest,

        # At the root of the chain, we support deriving from a tarball
        # base image.
        "legacy": parent_parts.get("legacy"),

        # The path to the v2.2 manifest file.
        "manifest": manifest_file,
        "manifest_digest": manifest_digest,

        # Keep track of all files/emptyfiles/symlinks that we have already added to the image layers.
        "transitive_files": transitive_files,

        # A list of paths to the layer .tar files
        "unzipped_layer": unzipped_layers,

        # A list of paths to the layer .tar.gz files
        "zipped_layer": zipped_layers,
    }

    # We support incrementally loading or assembling this single image
    # with a temporary name given by its build rule.
    images = {
        tag_name: container_parts,
    }

    _incr_load(
        ctx,
        images,
        output_executable,
        run = not ctx.attr.legacy_run_behavior,
        run_flags = docker_run_flags,
    )
    _assemble_image(
        ctx,
        images,
        output_tarball,
    )
    _assemble_image_digest(ctx, name, container_parts, output_tarball, output_digest)

    # Symlink config file for usage in structure tests
    ln_path = config_file.path.split("/")[-1]
    ctx.actions.run_shell(
        outputs = [output_config],
        inputs = [config_file],
        command = "ln -s %s %s" % (ln_path, output_config.path),
    )

    runfiles = ctx.runfiles(
        files = unzipped_layers + diff_ids + [config_file, config_digest] +
                ([container_parts["legacy"]] if container_parts["legacy"] else []),
    )

    return [
        ImageInfo(
            container_parts = container_parts,
            legacy_run_behavior = ctx.attr.legacy_run_behavior,
            docker_run_flags = docker_run_flags,
        ),
        DefaultInfo(
            executable = output_executable,
            files = depset([output_layer]),
            runfiles = runfiles,
        ),
    ]

_attrs = dicts.add(_layer.attrs, {
    "base": attr.label(allow_files = container_filetype),
    "cmd": attr.string_list(),
    "create_image_config": attr.label(
        default = Label("//container/go/cmd/create_image_config:create_image_config"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "creation_time": attr.string(),
    "docker_run_flags": attr.string(),
    "entrypoint": attr.string_list(),
    "label_file_strings": attr.string_list(),
    # Implicit/Undocumented dependencies.
    "label_files": attr.label_list(
        allow_files = True,
    ),
    "labels": attr.string_dict(),
    "launcher": attr.label(allow_single_file = True),
    "launcher_args": attr.string_list(default = []),
    "layers": attr.label_list(providers = [LayerInfo]),
    "legacy_repository_naming": attr.bool(default = False),
    "legacy_run_behavior": attr.bool(
        # TODO(mattmoor): Default this to False.
        default = True,
        doc = ("If set to False, `bazel run` will directly invoke `docker run` " +
               "with flags specified in the `docker_run_flags` attribute. " +
               "Note that it defaults to False when using <lang>_image rules."),
    ),
    # null_cmd and null_entrypoint are hidden attributes from users.
    # They are needed because specifying cmd or entrypoint as {None, [] or ""}
    # and not specifying them at all in the container_image rule would both make
    # ctx.attr.cmd or ctx.attr.entrypoint to be [].
    # We need these flags to distinguish them.
    "null_cmd": attr.bool(default = False),
    "null_entrypoint": attr.bool(default = False),
    "ports": attr.string_list(),  # Skylark doesn't support int_list...
    "repository": attr.string(default = "bazel"),
    "stamp": attr.bool(default = False),
    "user": attr.string(),
    "volumes": attr.string_list(),
    "workdir": attr.string(),
    "_digester": attr.label(
        default = "//container/go/cmd/digester",
        cfg = "host",
        executable = True,
    ),
}, _hash_tools, _layer_tools, _zip_tools)

_outputs = dict(_layer.outputs)

_outputs["out"] = "%{name}.tar"

_outputs["digest"] = "%{name}.digest"

_outputs["config"] = "%{name}.json"

image = struct(
    attrs = _attrs,
    outputs = _outputs,
    implementation = _impl,
)

container_image_ = rule(
    attrs = _attrs,
    executable = True,
    outputs = _outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _impl,
)

# This validates the two forms of value accepted by
# ENTRYPOINT and CMD, turning them into a canonical
# python list form.
#
# The Dockerfile construct:
#   ENTRYPOINT "/foo" for Linux:
# Results in:
#   "Entrypoint": [
#       "/bin/sh",
#       "-c",
#       "\"/foo\""
#   ],
#   ENTRYPOINT "foo" for Windows:
# Results in:
#   "Entrypoint": [
#       "%WinDir%\system32\cmd.exe",
#       "/c",
#       "\"foo\""
#   ],
# Whereas:
#   ENTRYPOINT ["/foo", "a"]
# Results in:
#   "Entrypoint": [
#       "/foo",
#       "a"
#   ],
# NOTE: prefacing a command with 'exec' just ends up with the former
def _validate_command(name, argument, operating_system):
    if type(argument) == type(""):
        if (operating_system == "windows"):
            return ["%WinDir%\\system32\\cmd.exe", "/c", argument]
        else:
            return ["/bin/sh", "-c", argument]
    elif type(argument) == type([]):
        return argument
    elif argument:
        fail("The %s attribute must be a string or list, if specified." % name)
    else:
        return None

# Produces a new container image tarball compatible with 'docker load', which
# is a single additional layer atop 'base'.  The goal is to have relatively
# complete support for building container image, from the Dockerfile spec.
#
# For more information see the 'Config' section of the image specification:
# https://github.com/opencontainers/image-spec/blob/v0.2.0/serialization.md
#
# Only 'name' is required. All other fields have sane defaults.
#
#   container_image(
#      name="...",
#      visibility="...",
#
#      # The base layers on top of which to overlay this layer,
#      # equivalent to FROM.
#      base="//another/build:rule",
#
#      # The base directory of the files, defaulted to
#      # the package of the input.
#      # All files structure relatively to that path will be preserved.
#      # A leading '/' mean the workspace root and this path is relative
#      # to the current package by default.
#      data_path="...",
#
#      # The directory in which to expand the specified files,
#      # defaulting to '/'.
#      # Only makes sense accompanying one of files/tars/debs.
#      directory="...",
#
#      # The set of archives to expand, or packages to install
#      # within the chroot of this layer
#      files=[...],
#      tars=[...],
#      debs=[...],
#
#      # The set of symlinks to create within a given layer.
#      symlinks = {
#          "/path/to/link": "/path/to/target",
#          ...
#      },
#
#      # Other layers built from container_layer rule
#      layers = [":c-lang-layer", ":java-lang-layer", ...]
#
#      # https://docs.docker.com/engine/reference/builder/#entrypoint
#      entrypoint="...", or
#      entrypoint=[...],            -- exec form
#      Set entrypoint to None, [] or "" will set the Entrypoint of the image to
#      be null.
#
#      # https://docs.docker.com/engine/reference/builder/#cmd
#      cmd="...", or
#      cmd=[...],                   -- exec form
#      Set cmd to None, [] or "" will set the Cmd of the image to be null.
#
#      # https://docs.docker.com/engine/reference/builder/#expose
#      ports=[...],
#
#      # https://docs.docker.com/engine/reference/builder/#user
#      # NOTE: the normal directive affects subsequent RUN, CMD,
#      # and ENTRYPOINT
#      user="...",
#
#      # https://docs.docker.com/engine/reference/builder/#volume
#      volumes=[...],
#
#      # https://docs.docker.com/engine/reference/builder/#workdir
#      # NOTE: the normal directive affects subsequent RUN, CMD,
#      # ENTRYPOINT, ADD, and COPY, but this attribute only affects
#      # the entry point.
#      workdir="...",
#
#      # https://docs.docker.com/engine/reference/builder/#env
#      env = {
#         "var1": "val1",
#         "var2": "val2",
#         ...
#         "varN": "valN",
#      },
#   )

def container_image(**kwargs):
    """Package a docker image.

  This rule generates a sequence of genrules the last of which is named 'name',
  so the dependency graph works out properly.  The output of this rule is a
  tarball compatible with 'docker save/load' with the structure:
    {layer-name}:
      layer.tar
      VERSION
      json
    {image-config-sha256}.json
    ...
    manifest.json
    repositories
    top     # an implementation detail of our rules, not consumed by Docker.
  This rule appends a single new layer to the tarball of this form provided
  via the 'base' parameter.

  The images produced by this rule are always named 'bazel/tmp:latest' when
  loaded (an internal detail).  The expectation is that the images produced
  by these rules will be uploaded using the 'docker_push' rule below.

  Args:
    **kwargs: See above.
  """
    operating_system = None

    if ("operating_system" in kwargs):
        operating_system = kwargs["operating_system"]
        if operating_system != "linux" and operating_system != "windows":
            fail(
                "invalid operating_system(%s) specified. Must be 'linux' or 'windows'" % operating_system,
                attr = operating_system,
            )

    reserved_attrs = [
        "label_files",
        "label_file_strings",
        "null_cmd",
        "null_entrypoint",
    ]

    for reserved in reserved_attrs:
        if reserved in kwargs:
            fail("reserved for internal use by container_image macro", attr = reserved)

    if "labels" in kwargs:
        files = sorted({v[1:]: None for v in kwargs["labels"].values() if v[0] == "@"}.keys())
        kwargs["label_files"] = files
        kwargs["label_file_strings"] = files

    # If cmd is set but set to None, [] or "",
    # we interpret it as users want to set it to null.
    if "cmd" in kwargs:
        if not kwargs["cmd"]:
            kwargs["null_cmd"] = True

            # _impl defines "cmd" as string_list. Turn "" into [] before
            # passing to it.
            if kwargs["cmd"] == "":
                kwargs["cmd"] = []
        else:
            kwargs["cmd"] = _validate_command("cmd", kwargs["cmd"], operating_system)

    # If entrypoint is set but set to None, [] or "",
    # we interpret it as users want to set it to null.
    if "entrypoint" in kwargs:
        if not kwargs["entrypoint"]:
            kwargs["null_entrypoint"] = True

            # _impl defines "entrypoint" as string_list. Turn "" into [] before
            # passing to it.
            if kwargs["entrypoint"] == "":
                kwargs["entrypoint"] = []
        else:
            kwargs["entrypoint"] = _validate_command("entrypoint", kwargs["entrypoint"], operating_system)

    container_image_(**kwargs)
