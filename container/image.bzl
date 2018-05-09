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
    "//skylib:label.bzl",
    _string_to_label = "string_to_label",
)
load(
    "//container:layer_tools.bzl",
    _assemble_image = "assemble",
    _get_layers = "get_from_target",
    _incr_load = "incremental_load",
    _layer_tools = "tools",
)
load(
    "//container:layer.bzl",
    "LayerInfo",
    _layer = "layer",
)
load(
    "//skylib:path.bzl",
    "dirname",
    "strip_prefix",
    _canonicalize_path = "canonicalize",
    _join_path = "join",
)
load(
    "//skylib:serialize.bzl",
    _serialize_dict = "dict_to_associative_list",
)

def _get_base_config(ctx, name, base):
    if ctx.files.base or base:
        # The base is the first layer in container_parts if provided.
        l = _get_layers(ctx, name, ctx.attr.base, base)
        return l.get("config")

def _image_config(
        ctx,
        name,
        layer_names,
        entrypoint = None,
        cmd = None,
        creation_time = None,
        env = None,
        base_config = None,
        layer_name = None):
    """Create the configuration for a new container image."""
    config = ctx.new_file(name + "." + layer_name + ".config")

    label_file_dict = _string_to_label(
        ctx.files.label_files,
        ctx.attr.label_file_strings,
    )

    labels = dict()
    for l in ctx.attr.labels:
        fname = ctx.attr.labels[l]
        if fname[0] == "@":
            labels[l] = "@" + label_file_dict[fname[1:]].path
        else:
            labels[l] = fname

    args = [
        "--output=%s" % config.path,
    ] + [
        "--entrypoint=%s" % x
        for x in entrypoint
    ] + [
        "--command=%s" % x
        for x in cmd
    ] + [
        "--ports=%s" % x
        for x in ctx.attr.ports
    ] + [
        "--volumes=%s" % x
        for x in ctx.attr.volumes
    ]
    if creation_time:
        args += ["--creation_time=%s" % creation_time]
    elif ctx.attr.stamp:
        # If stamping is enabled, and the creation_time is not manually defined,
        # default to '{BUILD_TIMESTAMP}'.
        args += ["--creation_time={BUILD_TIMESTAMP}"]

    _labels = _serialize_dict(labels)
    if _labels:
        args += ["--labels=%s" % x for x in _labels.split(",")]
    _env = _serialize_dict(env)
    if _env:
        args += ["--env=%s" % x for x in _env.split(",")]

    if ctx.attr.user:
        args += ["--user=" + ctx.attr.user]
    if ctx.attr.workdir:
        args += ["--workdir=" + ctx.attr.workdir]

    inputs = layer_names
    for layer_name in layer_names:
        args += ["--layer=@" + layer_name.path]

    if ctx.attr.label_files:
        inputs += ctx.files.label_files

    if base_config:
        args += ["--base=%s" % base_config.path]
        inputs += [base_config]

    if ctx.attr.stamp:
        stamp_inputs = [ctx.info_file, ctx.version_file]
        args += ["--stamp-info-file=%s" % f.path for f in stamp_inputs]
        inputs += stamp_inputs

    ctx.action(
        executable = ctx.executable.create_image_config,
        arguments = args,
        inputs = inputs,
        outputs = [config],
        use_default_shell_env = True,
        mnemonic = "ImageConfig",
    )
    return config, _sha256(ctx, config)

def _repository_name(ctx):
    """Compute the repository name for the current rule."""
    if ctx.attr.legacy_repository_naming:
        # Legacy behavior, off by default.
        return _join_path(ctx.attr.repository, ctx.label.package.replace("/", "_"))
        # Newer Docker clients support multi-level names, which are a part of
        # the v2 registry specification.

    return _join_path(ctx.attr.repository, ctx.label.package)

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
        output_executable = None,
        output_tarball = None,
        output_layer = None):
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
    output_executable: File to use as output for script to load docker image
    output_tarball: File, overrides ctx.outputs.out
    output_layer: File, overrides ctx.outputs.layer
  """
    name = name or ctx.label.name
    entrypoint = entrypoint or ctx.attr.entrypoint
    cmd = cmd or ctx.attr.cmd
    creation_time = creation_time or ctx.attr.creation_time
    output_executable = output_executable or ctx.outputs.executable
    output_tarball = output_tarball or ctx.outputs.out
    output_layer = output_layer or ctx.outputs.layer

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

    # Get the config for the base layer
    config_file = _get_base_config(ctx, name, base)

    # Generate the new config layer by layer, using the attributes specified and the diff_id
    for i, layer in enumerate(layers):
        config_file, config_digest = _image_config(
            ctx,
            name = name,
            layer_names = [layer_diff_ids[i]],
            entrypoint = entrypoint,
            cmd = cmd,
            creation_time = creation_time,
            env = layer.env,
            base_config = config_file,
            layer_name = str(i),
        )

        # Construct a temporary name based on the build target.
    tag_name = _repository_name(ctx) + ":" + name

    # These are the constituent parts of the Container image, which each
    # rule in the chain must preserve.
    container_parts = {
        # The path to the v2.2 configuration file.
        "config": config_file,
        "config_digest": config_digest,

        # A list of paths to the layer .tar.gz files
        "zipped_layer": zipped_layers,
        # A list of paths to the layer digests.
        "blobsum": shas,

        # A list of paths to the layer .tar files
        "unzipped_layer": unzipped_layers,
        # A list of paths to the layer diff_ids.
        "diff_id": diff_ids,

        # At the root of the chain, we support deriving from a tarball
        # base image.
        "legacy": parent_parts.get("legacy"),
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
        run_flags = ctx.attr.docker_run_flags,
    )
    _assemble_image(ctx, images, output_tarball)

    runfiles = ctx.runfiles(
        files = unzipped_layers + diff_ids + [config_file, config_digest] +
                ([container_parts["legacy"]] if container_parts["legacy"] else []),
    )
    return struct(
        runfiles = runfiles,
        files = depset([output_layer]),
        container_parts = container_parts,
    )

_attrs = dict(_layer.attrs.items() + {
    "base": attr.label(allow_files = container_filetype),
    "legacy_repository_naming": attr.bool(default = False),
    # TODO(mattmoor): Default this to False.
    "legacy_run_behavior": attr.bool(default = True),
    # Run the container using host networking, so that the service is
    # available to the developer without having to poke around with
    # docker inspect.
    "docker_run_flags": attr.string(
        default = "-i --rm --network=host",
    ),
    "user": attr.string(),
    "labels": attr.string_dict(),
    "cmd": attr.string_list(),
    "creation_time": attr.string(),
    "entrypoint": attr.string_list(),
    "ports": attr.string_list(),  # Skylark doesn't support int_list...
    "volumes": attr.string_list(),
    "workdir": attr.string(),
    "layers": attr.label_list(providers = [LayerInfo]),
    "repository": attr.string(default = "bazel"),
    "stamp": attr.bool(default = False),
    # Implicit/Undocumented dependencies.
    "label_files": attr.label_list(
        allow_files = True,
    ),
    "label_file_strings": attr.string_list(),
    "create_image_config": attr.label(
        default = Label("//container:create_image_config"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}.items() + _hash_tools.items() + _layer_tools.items())

_outputs = _layer.outputs + {
    "out": "%{name}.tar",
}

image = struct(
    attrs = _attrs,
    outputs = _outputs,
    implementation = _impl,
)

container_image_ = rule(
    attrs = _attrs,
    executable = True,
    outputs = _outputs,
    implementation = _impl,
)

# This validates the two forms of value accepted by
# ENTRYPOINT and CMD, turning them into a canonical
# python list form.
#
# The Dockerfile construct:
#   ENTRYPOINT "/foo"
# Results in:
#   "Entrypoint": [
#       "/bin/sh",
#       "-c",
#       "\"/foo\""
#   ],
# Whereas:
#   ENTRYPOINT ["/foo", "a"]
# Results in:
#   "Entrypoint": [
#       "/foo",
#       "a"
#   ],
# NOTE: prefacing a command with 'exec' just ends up with the former
def _validate_command(name, argument):
    if type(argument) == type(""):
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
        #
        #      # https://docs.docker.com/engine/reference/builder/#cmd
        #      cmd="...", or
        #      cmd=[...],                   -- exec form
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
    if "cmd" in kwargs:
        kwargs["cmd"] = _validate_command("cmd", kwargs["cmd"])
    for reserved in ["label_files", "label_file_strings"]:
        if reserved in kwargs:
            fail("reserved for internal use by container_image macro", attr = reserved)
    if "labels" in kwargs:
        files = sorted({v[1:]: None for v in kwargs["labels"].values() if v[0] == "@"}.keys())
        kwargs["label_files"] = files
        kwargs["label_file_strings"] = files
    if "entrypoint" in kwargs:
        kwargs["entrypoint"] = _validate_command("entrypoint", kwargs["entrypoint"])
    container_image_(**kwargs)
