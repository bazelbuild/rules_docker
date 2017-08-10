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
"""Rule for building a Docker image.

In addition to the base docker_build rule, we expose its constituents
(attr, outputs, implementation) directly so that others may expose a
more specialized build leveraging the same implementation.  The
expectation in such cases is that users will write something like:

  load(
    "@io_bazel_rules_docker//docker:docker.bzl",
    _docker="docker",
  )

  def _impl(ctx):
    ...
    return _docker.build.implementation(ctx, ... kwarg overrides ...)

  _foo_image = rule(
      attrs = _docker.build.attrs + {
         # My attributes, or overrides of _build_attrs defaults.
         ...
      },
      executable = True,
      outputs = _docker.build.outputs,
      implementation = _impl,
  )

"""

load(
    ":filetype.bzl",
    deb_filetype = "deb",
    docker_filetype = "docker",
    tar_filetype = "tar",
)
load(
    ":hash.bzl",
    _hash_tools = "tools",
    _sha256 = "sha256",
)
load(
    ":zip.bzl",
    _gzip = "gzip",
)
load(
    ":label.bzl",
    _string_to_label = "string_to_label",
)
load(
    ":layers.bzl",
    _assemble_image = "assemble",
    _get_layers = "get_from_target",
    _incr_load = "incremental_load",
    _layer_tools = "tools",
)
load(
    ":path.bzl",
    "dirname",
    "strip_prefix",
    _canonicalize_path = "canonicalize",
    _join_path = "join",
)
load(
    ":serialize.bzl",
    _serialize_dict = "dict_to_associative_list",
)

def magic_path(ctx, f):
  # Right now the logic this uses is a bit crazy/buggy, so to support
  # bug-for-bug compatibility in the foo_image rules, expose the logic.
  # See also: https://github.com/bazelbuild/rules_docker/issues/106
  # See also: https://groups.google.com/forum/#!topic/bazel-discuss/1lX3aiTZX3Y

  if ctx.attr.data_path:
    # If data_prefix is specified, then add files relative to that.
    data_path = _join_path(
        dirname(ctx.outputs.out.short_path),
        _canonicalize_path(ctx.attr.data_path))
    return strip_prefix(f.short_path, data_path)
  else:
    # Otherwise, files are added without a directory prefix at all.
    return f.basename

def _build_layer(ctx, files=None, directory=None, symlinks=None):
  """Build the current layer for appending it the base layer.

  Args:
    files: File list, overrides ctx.files.files
    directory: str, overrides ctx.attr.directory
    symlinks: str Dict, overrides ctx.attr.symlinks
  """

  layer = ctx.outputs.layer
  build_layer = ctx.executable.build_layer
  args = [
      "--output=" + layer.path,
      "--directory=" + directory,
      "--mode=" + ctx.attr.mode,
  ]

  args += ["--file=%s=%s" % (f.path, magic_path(ctx, f))
           for f in files]

  args += ["--tar=" + f.path for f in ctx.files.tars]
  args += ["--deb=" + f.path for f in ctx.files.debs if f.path.endswith(".deb")]
  for k in symlinks:
    if ':' in k:
      fail("The source of a symlink cannot contain ':', got: %s" % k)
  args += ["--link=%s:%s" % (k, symlinks[k])
           for k in symlinks]
  arg_file = ctx.new_file(ctx.label.name + ".layer.args")
  ctx.file_action(arg_file, "\n".join(args))

  ctx.action(
      executable = build_layer,
      arguments = ["--flagfile=" + arg_file.path],
      inputs = files + ctx.files.tars + ctx.files.debs + [arg_file],
      outputs = [layer],
      use_default_shell_env=True,
      mnemonic="DockerLayer"
  )
  return layer, _sha256(ctx, layer)

def _zip_layer(ctx, layer):
  zipped_layer = _gzip(ctx, layer)
  return zipped_layer, _sha256(ctx, zipped_layer)

def _get_base_config(ctx):
  if ctx.files.base:
    # The base is the first layer in docker_parts if provided.
    l = _get_layers(ctx, ctx.attr.base, ctx.files.base)
    return l.get("config")

def _image_config(ctx, layer_name, entrypoint=None, cmd=None):
  """Create the configuration for a new docker image."""
  config = ctx.new_file(ctx.label.name + ".config")

  label_file_dict = _string_to_label(
      ctx.files.label_files, ctx.attr.label_file_strings)

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
      "--entrypoint=%s" % x for x in entrypoint
  ] + [
      "--command=%s" % x for x in cmd
  ] + [
      "--ports=%s" % x for x in ctx.attr.ports
  ] + [
      "--volumes=%s" % x for x in ctx.attr.volumes
  ]
  _labels = _serialize_dict(labels)
  if _labels:
    args += ["--labels=%s" % x for x in _labels.split(',')]
  _env = _serialize_dict(ctx.attr.env)
  if _env:
    args += ["--env=%s" % x for x in _env.split(',')]

  if ctx.attr.user:
    args += ["--user=" + ctx.attr.user]
  if ctx.attr.workdir:
    args += ["--workdir=" + ctx.attr.workdir]

  inputs = [layer_name]
  args += ["--layer=@" + layer_name.path]

  if ctx.attr.label_files:
    inputs += ctx.files.label_files

  base = _get_base_config(ctx)
  if base:
    args += ["--base=%s" % base.path]
    inputs += [base]

  ctx.action(
      executable = ctx.executable.create_image_config,
      arguments = args,
      inputs = inputs,
      outputs = [config],
      use_default_shell_env=True,
      mnemonic = "ImageConfig")
  return config, _sha256(ctx, config)

def _repository_name(ctx):
  """Compute the repository name for the current rule."""
  if ctx.attr.legacy_repository_naming:
    # Legacy behavior, off by default.
    return _join_path(ctx.attr.repository, ctx.label.package.replace("/", "_"))
  # Newer Docker clients support multi-level names, which are a part of
  # the v2 registry specification.
  return _join_path(ctx.attr.repository, ctx.label.package)

def _impl(ctx, files=None, directory=None,
          entrypoint=None, cmd=None, symlinks=None):
  """Implementation for the docker_build rule.

  Args:
    ctx: The bazel rule context
    files: File list, overrides ctx.files.files
    directory: str, overrides ctx.attr.directory
    entrypoint: str List, overrides ctx.attr.entrypoint
    cmd: str List, overrides ctx.attr.cmd
    symlinks: str Dict, overrides ctx.attr.symlinks
  """

  files = files or ctx.files.files
  directory = directory or ctx.attr.directory
  entrypoint = entrypoint or ctx.attr.entrypoint
  cmd = cmd or ctx.attr.cmd
  symlinks = symlinks or ctx.attr.symlinks

  # Generate the unzipped filesystem layer, and its sha256 (aka diff_id).
  unzipped_layer, diff_id = _build_layer(ctx, files=files,
                                         directory=directory, symlinks=symlinks)

  # Generate the zipped filesystem layer, and its sha256 (aka blob sum)
  zipped_layer, blob_sum = _zip_layer(ctx, unzipped_layer)

  # Generate the new config using the attributes specified and the diff_id
  config_file, config_digest = _image_config(
    ctx, diff_id, entrypoint=entrypoint, cmd=cmd)

  # Construct a temporary name based on the build target.
  tag_name = _repository_name(ctx) + ":" + ctx.label.name

  # Get the layers and shas from our base.
  # These are ordered as they'd appear in the v2.2 config,
  # so they grow at the end.
  parent_parts = _get_layers(ctx, ctx.attr.base, ctx.files.base)
  zipped_layers = parent_parts.get("zipped_layer", []) + [zipped_layer]
  shas = parent_parts.get("blobsum", []) + [blob_sum]
  unzipped_layers = parent_parts.get("unzipped_layer", []) + [unzipped_layer]
  diff_ids = parent_parts.get("diff_id", []) + [diff_id]

  # These are the constituent parts of the Docker image, which each
  # rule in the chain must preserve.
  docker_parts = {
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
      tag_name: docker_parts
  }

  _incr_load(ctx, images, ctx.outputs.executable)
  _assemble_image(ctx, images, ctx.outputs.out)

  runfiles = ctx.runfiles(
      files = unzipped_layers + diff_ids + [config_file, config_digest] +
      ([docker_parts["legacy"]] if docker_parts["legacy"] else []))
  return struct(runfiles = runfiles,
                files = set([ctx.outputs.layer]),
                docker_parts = docker_parts)

_attrs = {
    "base": attr.label(allow_files = docker_filetype),
    "data_path": attr.string(),
    "directory": attr.string(default = "/"),
    "tars": attr.label_list(allow_files = tar_filetype),
    "debs": attr.label_list(allow_files = deb_filetype),
    "files": attr.label_list(allow_files = True),
    "legacy_repository_naming": attr.bool(default = False),
    "mode": attr.string(default = "0555"),  # 0555 == a+rx
    "symlinks": attr.string_dict(),
    "entrypoint": attr.string_list(),
    "cmd": attr.string_list(),
    "user": attr.string(),
    "env": attr.string_dict(),
    "labels": attr.string_dict(),
    "ports": attr.string_list(),  # Skylark doesn't support int_list...
    "volumes": attr.string_list(),
    "workdir": attr.string(),
    "repository": attr.string(default = "bazel"),
    # Implicit dependencies.
    "label_files": attr.label_list(
        allow_files = True,
    ),
    "label_file_strings": attr.string_list(),
    "build_layer": attr.label(
        default = Label("//docker:build_tar"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "create_image_config": attr.label(
        default = Label("//docker:create_image_config"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
} + _hash_tools + _layer_tools

_outputs = {
    "out": "%{name}.tar",
    "layer": "%{name}-layer.tar",
}

build = struct(
    attrs = _attrs,
    outputs = _outputs,
    implementation = _impl,
)

docker_build_ = rule(
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
  if type(argument) == "string":
    return ["/bin/sh", "-c", argument]
  elif type(argument) == "list":
    return argument
  elif argument:
    fail("The %s attribute must be a string or list, if specified." % name)
  else:
    return None

# Produces a new docker image tarball compatible with 'docker load', which
# is a single additional layer atop 'base'.  The goal is to have relatively
# complete support for building docker image, from the Dockerfile spec.
#
# For more information see the 'Config' section of the image specification:
# https://github.com/opencontainers/image-spec/blob/v0.2.0/serialization.md
#
# Only 'name' is required. All other fields have sane defaults.
#
#   docker_build(
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
def docker_build(**kwargs):
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
      fail("reserved for internal use by docker_build macro", attr=reserved)
  if "labels" in kwargs:
    files = sorted(set([v[1:] for v in kwargs["labels"].values() if v[0] == "@"]))
    kwargs["label_files"] = files
    kwargs["label_file_strings"] = files
  if "entrypoint" in kwargs:
    kwargs["entrypoint"] = _validate_command("entrypoint", kwargs["entrypoint"])
  docker_build_(**kwargs)
