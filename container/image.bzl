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
more specialized build leveraging the same implementation.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "//skylib:hash.bzl",
    _hash_tools = "tools",
    _sha256 = "sha256",
)
load(
    "@io_bazel_rules_docker//container:providers.bzl",
    "ImageInfo",
    "LayerInfo",
    "STAMP_ATTR",
    "StampSettingInfo",
)
load(
    "//container:layer.bzl",
    _layer = "layer",
)
load(
    "//container:layer_tools.bzl",
    _assemble_image = "assemble",
    _gen_img_args = "generate_args_for_image",
    _get_layers_from_archive_file = "get_from_archive_file",
    _get_layers_from_target = "get_from_target",
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

def _add_create_image_config_args(
        ctx,
        args,
        inputs,
        manifest,
        config,
        labels,
        label_files,
        entrypoint,
        cmd,
        null_cmd,
        null_entrypoint,
        creation_time,
        env,
        workdir,
        user,
        layer_names,
        base_config,
        base_manifest,
        architecture,
        operating_system,
        os_version):
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

    stamp = ctx.attr.stamp[StampSettingInfo].value

    if creation_time:
        args.add("-creationTime", creation_time)
    elif stamp:
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

    if user:
        args.add("-user", user)
    if workdir:
        args.add("-workdir", workdir)

    inputs += layer_names
    args.add_all(layer_names, before_each = "-layerDigestFile", format_each = "@%s")

    if label_files:
        inputs += label_files

    if base_config:
        args.add("-baseConfig", base_config)
        inputs.append(base_config)

    if base_manifest:
        args.add("-baseManifest", base_manifest)
        inputs.append(base_manifest)

    if architecture:
        args.add("-architecture", architecture)

    if operating_system:
        args.add("-operatingSystem", operating_system)

    if os_version:
        args.add("-osVersion", os_version)

    if stamp:
        stamp_inputs = [ctx.info_file, ctx.version_file]
        args.add_all(stamp_inputs, before_each = "-stampInfoFile")
        inputs += stamp_inputs

    if ctx.attr.launcher_args and not ctx.attr.launcher:
        fail("launcher_args does nothing when launcher is not specified.", attr = "launcher_args")
    if ctx.attr.launcher:
        args.add("-entrypointPrefix", ctx.file.launcher.basename, format = "/%s")
        args.add_all(ctx.attr.launcher_args, before_each = "-entrypointPrefix")

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
        architecture = None,
        operating_system = None,
        os_version = None,
        layer_name = None,
        workdir = None,
        user = None,
        null_entrypoint = False,
        null_cmd = False,
        labels = None,
        label_files = None,
        label_file_strings = None):
    """Create the configuration for a new container image."""
    config = ctx.actions.declare_file(name + "." + layer_name + ".config")
    manifest = ctx.actions.declare_file(name + "." + layer_name + ".manifest")

    label_file_dict = _string_to_label(
        label_files,
        label_file_strings,
    )

    labels_fixed = dict()
    for label in labels:
        fname = labels[label]
        if fname[0] == "@":
            labels_fixed[label] = "@" + label_file_dict[fname[1:]].path
        else:
            labels_fixed[label] = fname

    args = ctx.actions.args()
    inputs = []
    executable = None

    _add_create_image_config_args(
        ctx,
        args,
        inputs,
        manifest,
        config,
        labels_fixed,
        label_files,
        entrypoint,
        cmd,
        null_cmd,
        null_entrypoint,
        creation_time,
        env,
        workdir,
        user,
        layer_names,
        base_config,
        base_manifest,
        architecture,
        operating_system,
        os_version,
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
        return _join_path(ctx.attr.repository, ctx.label.package.lower().replace("/", "_"))

    # Newer Docker clients support multi-level names, which are a part of
    # the v2 registry specification.

    return _join_path(ctx.attr.repository, ctx.label.package.lower())

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
        compression = None,
        compression_options = None,
        experimental_tarball_format = None,
        debs = None,
        tars = None,
        architecture = None,
        operating_system = None,
        os_version = None,
        output_executable = None,
        output_tarball = None,
        output_config = None,
        output_config_digest = None,
        output_digest = None,
        output_layer = None,
        workdir = None,
        user = None,
        null_cmd = None,
        null_entrypoint = None,
        tag_name = None,
        labels = None,
        label_files = None,
        label_file_strings = None):
    """Implementation for the container_image rule.

    You can write a customized container_image rule by writing something like:

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
            cfg = _container.image.cfg,
        )

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
        compression: str, overrides ctx.attr.compression
        compression_options: str list, overrides ctx.attr.compression_options
        experimental_tarball_format: str, overrides ctx.attr.experimental_tarball_format
        debs: File list, overrides ctx.files.debs
        tars: File list, overrides ctx.files.tars
        architecture: str, overrides ctx.attr.architecture
        operating_system: Operating system to target (e.g. linux, windows)
        os_version: Operating system version to target
        output_executable: File to use as output for script to load docker image
        output_tarball: File, overrides ctx.outputs.out
        output_config: File, overrides ctx.outputs.config
        output_config_digest: File, overrides ctx.outputs.config_digest
        output_digest: File, overrides ctx.outputs.digest
        output_layer: File, overrides ctx.outputs.layer
        workdir: str, overrides ctx.attr.workdir
        user: str, overrides ctx.attr.user
        null_cmd: bool, overrides ctx.attr.null_cmd
        null_entrypoint: bool, overrides ctx.attr.null_entrypoint
        tag_name: str, overrides ctx.attr.tag_name
        labels: str Dict, overrides ctx.attr.labels
        label_files: File list, overrides ctx.attr.label_files
        label_file_strings: str list, overrides ctx.attr.label_file_strings
    """
    name = name or ctx.label.name
    base = base or ctx.attr.base
    entrypoint = entrypoint or ctx.attr.entrypoint
    cmd = cmd or ctx.attr.cmd
    architecture = architecture or ctx.attr.architecture
    compression = compression or ctx.attr.compression
    compression_options = compression_options or ctx.attr.compression_options
    experimental_tarball_format = experimental_tarball_format or ctx.attr.experimental_tarball_format
    operating_system = operating_system or ctx.attr.operating_system
    os_version = os_version or ctx.attr.os_version
    creation_time = creation_time or ctx.attr.creation_time
    build_executable = output_executable or ctx.outputs.build_script
    output_tarball = output_tarball or ctx.outputs.out
    output_digest = output_digest or ctx.outputs.digest
    output_config = output_config or ctx.outputs.config
    output_config_digest = output_config_digest or ctx.outputs.config_digest
    output_layer = output_layer or ctx.outputs.layer
    build_script = ctx.outputs.build_script
    null_cmd = null_cmd or ctx.attr.null_cmd
    null_entrypoint = null_entrypoint or ctx.attr.null_entrypoint
    tag_name = tag_name or ctx.attr.tag_name
    labels = labels or ctx.attr.labels
    label_files = label_files or ctx.files.label_files
    label_file_strings = label_file_strings or ctx.attr.label_file_strings

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
        compression = compression,
        compression_options = compression_options,
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
    if hasattr(base, "basename"):
        parent_parts = _get_layers_from_archive_file(ctx, name, base)
    else:
        parent_parts = _get_layers_from_target(ctx, name, base)
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
    config_file = parent_parts.get("config")
    config_digest = None

    # Get the manifest for the base layer
    manifest_file = parent_parts.get("manifest")
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
            architecture = architecture,
            operating_system = operating_system,
            os_version = os_version,
            layer_name = str(i),
            workdir = workdir or ctx.attr.workdir,
            user = user or ctx.attr.user,
            null_entrypoint = null_entrypoint,
            null_cmd = null_cmd,
            labels = labels,
            label_files = label_files,
            label_file_strings = label_file_strings,
        )

    # Construct a temporary name based on the build target. This is the name
    # of the docker container.
    final_tag = tag_name if tag_name else name
    container_name = "{}:{}".format(_repository_name(ctx), final_tag)

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
        container_name: container_parts,
    }

    _incr_load(
        ctx,
        images,
        build_executable,
        run = not ctx.attr.legacy_run_behavior,
        run_flags = docker_run_flags,
    )

    _assemble_image(
        ctx,
        images,
        output_tarball,
        experimental_tarball_format,
    )
    _assemble_image_digest(ctx, name, container_parts, output_tarball, output_digest)

    # Copy config file and its sha file for usage in tests
    ctx.actions.run_shell(
        outputs = [output_config],
        inputs = [config_file],
        command = "cp %s %s" % (config_file.path, output_config.path),
    )
    ctx.actions.run_shell(
        outputs = [output_config_digest],
        inputs = [config_digest],
        command = "cp %s %s" % (config_digest.path, output_config_digest.path),
    )

    runfiles = ctx.runfiles(
        files = unzipped_layers + diff_ids + [config_file, config_digest, output_config_digest] +
                ([container_parts["legacy"]] if container_parts["legacy"] else []),
    )

    return [
        ImageInfo(
            container_parts = container_parts,
            legacy_run_behavior = ctx.attr.legacy_run_behavior,
            docker_run_flags = docker_run_flags,
        ),
        DefaultInfo(
            executable = build_executable,
            files = depset([output_layer]),
            runfiles = runfiles,
        ),
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["files"],
        ),
    ]

_attrs = dicts.add(_layer.attrs, {
    "architecture": attr.string(
        doc = "The desired CPU architecture to be used as label in the container image.",
        default = "amd64",
    ),
    "base": attr.label(
        allow_files = container_filetype,
        doc = "The base layers on top of which to overlay this layer, equivalent to FROM.",
    ),
    "cmd": attr.string_list(
        doc = """List of commands to execute in the image.

        See https://docs.docker.com/engine/reference/builder/#cmd

        The behavior between using `""` and `[]` may differ.
        Please see [#1448](https://github.com/bazelbuild/rules_docker/issues/1448)
        for more details.

        Set `cmd` to `None`, `[]` or `""` will set the `Cmd` of the image to be
        `null`.

        This field supports stamp variables.""",
    ),
    "compression": attr.string(
        default = "gzip",
        doc = """Compression method for image layer. Currently only gzip is supported.

        This affects the compressed layer, which is by the `container_push` rule.
        It doesn't affect the layers specified by the `layers` attribute.""",
    ),
    "compression_options": attr.string_list(
        doc = """Command-line options for the compression tool. Possible values depend on `compression` method.

        This affects the compressed layer, which is used by the `container_push` rule.
        It doesn't affect the layers specified by the `layers` attribute.""",
    ),
    "create_image_config": attr.label(
        default = Label("//container/go/cmd/create_image_config:create_image_config"),
        cfg = "exec",
        executable = True,
        allow_files = True,
    ),
    "creation_time": attr.string(
        doc = """The image's creation timestamp.

        Acceptable formats: Integer or floating point seconds since Unix Epoch, RFC 3339 date/time.

        This field supports stamp variables.

        If not set, defaults to {BUILD_TIMESTAMP} when stamp = True, otherwise 0""",
    ),
    "docker_run_flags": attr.string(
        doc = """Optional flags to use with `docker run` command.

        Only used when `legacy_run_behavior` is set to `False`.""",
    ),
    "entrypoint": attr.string_list(
        doc = """List of entrypoints to add in the image.

        See https://docs.docker.com/engine/reference/builder/#entrypoint

        Set `entrypoint` to `None`, `[]` or `""` will set the `Entrypoint` of the image
        to be `null`.

        The behavior between using `""` and `[]` may differ.
        Please see [#1448](https://github.com/bazelbuild/rules_docker/issues/1448)
        for more details.

        This field supports stamp variables.""",
    ),
    "experimental_tarball_format": attr.string(
        values = [
            "legacy",
            "compressed",
        ],
        default = "legacy",
        doc = ("The tarball format to use when producing an image .tar file. " +
               "Defaults to \"legacy\", which contains uncompressed layers. " +
               "If set to \"compressed\", the resulting tarball will contain " +
               "compressed layers, but is only loadable by newer versions of " +
               "docker. This is an experimental attribute, which is subject " +
               "to change or removal: do not depend on its exact behavior."),
    ),
    "label_file_strings": attr.string_list(),
    # Implicit/Undocumented dependencies.
    "label_files": attr.label_list(
        allow_files = True,
    ),
    "labels": attr.string_dict(
        doc = """Dictionary from custom metadata names to their values.

        See https://docs.docker.com/engine/reference/builder/#label

        You can also put a file name prefixed by '@' as a value.
        Then the value is replaced with the contents of the file.

        Example:

            labels = {
                "com.example.foo": "bar",
                "com.example.baz": "@metadata.json",
                ...
            },

        The values of this field support stamp variables.""",
    ),
    "launcher": attr.label(
        allow_single_file = True,
        doc = """If present, prefix the image's ENTRYPOINT with this file.

        Note that the launcher should be a container-compatible (OS & Arch)
        single executable file without any runtime dependencies (as none
        of its runfiles will be included in the image).""",
    ),
    "launcher_args": attr.string_list(
        default = [],
        doc = """Optional arguments for the `launcher` attribute.

        Only valid when `launcher` is specified.""",
    ),
    "layers": attr.label_list(
        doc = """List of `container_layer` targets.

        The data from each `container_layer` will be part of container image,
        and the environment variable will be available in the image as well.""",
        providers = [LayerInfo],
    ),
    "legacy_repository_naming": attr.bool(
        default = False,
        doc = """Whether to use the legacy strategy for setting the repository name
          embedded in the resulting tarball.

          e.g. `bazel/{target.replace('/', '_')}` vs. `bazel/{target}`""",
    ),
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
    "os_version": attr.string(
        doc = "The desired OS version to be used in the container image config.",
    ),
    # Starlark doesn't support int_list...
    "ports": attr.string_list(
        doc = """List of ports to expose.

        See https://docs.docker.com/engine/reference/builder/#expose""",
    ),
    "repository": attr.string(
        default = "bazel",
        doc = """The repository for the default tag for the image.

        Images generated by `container_image` are tagged by default to
        `bazel/package_name:target` for a `container_image` target at
        `//package/name:target`.

        Setting this attribute to `gcr.io/dummy` would set the default tag to
        `gcr.io/dummy/package_name:target`.""",
    ),
    "stamp": STAMP_ATTR,
    "user": attr.string(
        doc = """The user that the image should run as.

        See https://docs.docker.com/engine/reference/builder/#user

        Because building the image never happens inside a Docker container,
        this user does not affect the other actions (e.g., adding files).

        This field supports stamp variables.""",
    ),
    "volumes": attr.string_list(
        doc = """List of volumes to mount.

        See https://docs.docker.com/engine/reference/builder/#volumes""",
    ),
    "workdir": attr.string(
        doc = """Initial working directory when running the Docker image.

        See https://docs.docker.com/engine/reference/builder/#workdir

        Because building the image never happens inside a Docker container,
        this working directory does not affect the other actions (e.g., adding files).

        This field supports stamp variables.""",
    ),
    "tag_name": attr.string(
        doc = """Override final tag name. If unspecified, is set to name.""",
    ),
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
    "_digester": attr.label(
        default = "//container/go/cmd/digester",
        cfg = "exec",
        executable = True,
    ),
}, _hash_tools, _layer_tools)

_outputs = dict(_layer.outputs)

_outputs["out"] = "%{name}.tar"

_outputs["digest"] = "%{name}.digest"

_outputs["config"] = "%{name}.json"

_outputs["config_digest"] = "%{name}.json.sha256"

_outputs["build_script"] = "%{name}.executable"

def _image_transition_impl(settings, attr):
    if not settings["@io_bazel_rules_docker//transitions:enable"]:
        # Once bazel < 5.0 is not supported we can return an empty dict here
        return {
            "//command_line_option:platforms": settings["//command_line_option:platforms"],
            "@io_bazel_rules_docker//platforms:image_transition_cpu": "//plaftorms:image_transition_cpu_unset",
            "@io_bazel_rules_docker//platforms:image_transition_os": "//plaftorms:image_transition_os_unset",
        }

    return {
        "//command_line_option:platforms": "@io_bazel_rules_docker//platforms:image_transition",
        "@io_bazel_rules_docker//platforms:image_transition_cpu": "@platforms//cpu:" + {
            # Architecture aliases.
            "386": "x86_32",
            "amd64": "x86_64",
            "ppc64le": "ppc",
        }.get(attr.architecture, attr.architecture),
        "@io_bazel_rules_docker//platforms:image_transition_os": "@platforms//os:" + attr.operating_system,
    }

_image_transition = transition(
    implementation = _image_transition_impl,
    inputs = [
        "@io_bazel_rules_docker//transitions:enable",
        "//command_line_option:platforms",
    ],
    outputs = [
        "//command_line_option:platforms",
        "@io_bazel_rules_docker//platforms:image_transition_cpu",
        "@io_bazel_rules_docker//platforms:image_transition_os",
    ],
)

image = struct(
    attrs = _attrs,
    outputs = _outputs,
    implementation = _impl,
    cfg = _image_transition,
)

container_image_ = rule(
    attrs = image.attrs,
    doc = "Called by the `container_image` macro with **kwargs, see below",
    executable = True,
    outputs = image.outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = image.implementation,
    cfg = image.cfg,
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

def container_image(**kwargs):
    """Package a docker image.

    Produces a new container image tarball compatible with 'docker load', which
    is a single additional layer atop 'base'.  The goal is to have relatively
    complete support for building container image, from the Dockerfile spec.

    For more information see the 'Config' section of the image specification:
    https://github.com/opencontainers/image-spec/blob/v0.2.0/serialization.md

    Only 'name' is required. All other fields have sane defaults.

        container_image(
            name="...",
            visibility="...",

            # The base layers on top of which to overlay this layer,
            # equivalent to FROM.
            base="//another/build:rule",

            # The base directory of the files, defaulted to
            # the package of the input.
            # All files structure relatively to that path will be preserved.
            # A leading '/' mean the workspace root and this path is relative
            # to the current package by default.
            data_path="...",

            # The directory in which to expand the specified files,
            # defaulting to '/'.
            # Only makes sense accompanying one of files/tars/debs.
            directory="...",

            # The set of archives to expand, or packages to install
            # within the chroot of this layer
            files=[...],
            tars=[...],
            debs=[...],

            # The set of symlinks to create within a given layer.
            symlinks = {
                "/path/to/link": "/path/to/target",
                ...
            },

            # Other layers built from container_layer rule
            layers = [":c-lang-layer", ":java-lang-layer", ...]

            # https://docs.docker.com/engine/reference/builder/#entrypoint
            entrypoint="...", or
            entrypoint=[...],            -- exec form
            Set entrypoint to None, [] or "" will set the Entrypoint of the image to
            be null.

            # https://docs.docker.com/engine/reference/builder/#cmd
            cmd="...", or
            cmd=[...],                   -- exec form
            Set cmd to None, [] or "" will set the Cmd of the image to be null.

            # https://docs.docker.com/engine/reference/builder/#expose
            ports=[...],

            # https://docs.docker.com/engine/reference/builder/#user
            # NOTE: the normal directive affects subsequent RUN, CMD,
            # and ENTRYPOINT
            user="...",

            # https://docs.docker.com/engine/reference/builder/#volume
            volumes=[...],

            # https://docs.docker.com/engine/reference/builder/#workdir
            # NOTE: the normal directive affects subsequent RUN, CMD,
            # ENTRYPOINT, ADD, and COPY, but this attribute only affects
            # the entry point.
            workdir="...",

            # https://docs.docker.com/engine/reference/builder/#env
            env = {
                "var1": "val1",
                "var2": "val2",
                ...
                "varN": "valN",
            },

            # Compression method and command-line options.
            compression = "gzip",
            compression_options = ["--fast"],
            experimental_tarball_format = "compressed",
        )

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

    The images produced by this rule are always named `bazel/tmp:latest` when
    loaded (an internal detail).  The expectation is that the images produced
    by these rules will be uploaded using the `docker_push` rule below.

    The implicit output targets are:

    - `[name].tar`: A full Docker image containing all the layers, identical to
        what `docker save` would return. This is only generated on demand.
    - `[name].digest`: An image digest that can be used to refer to that image. Unlike tags,
        digest references are immutable i.e. always refer to the same content.
    - `[name]-layer.tar`: A Docker image containing only the layer corresponding to
        that target. It is used for incremental loading of the layer.

        **Note:** this target is not suitable for direct consumption.
        It is used for incremental loading and non-docker rules should
        depend on the Docker image (`[name].tar`) instead.
    - `[name]`: The incremental image loader. It will load only changed
            layers inside the Docker registry.

    This rule references the `@io_bazel_rules_docker//toolchains/docker:toolchain_type`.
    See [How to use the Docker Toolchain](/toolchains/docker/readme.md#how-to-use-the-docker-toolchain) for details.

    Args:
        **kwargs: Attributes are described by `container_image_` above.
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
