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
"""Tools for dealing with Docker Image layers."""

load(
    "@io_bazel_rules_docker//container:providers.bzl",
    "ImageInfo",
    "ImportInfo",
)
load(
    "//skylib:path.bzl",
    _get_runfile_path = "runfile",
)
load(
    "//skylib:docker.bzl",
    "docker_path",
)

def _extract_layers(ctx, name, artifact):
    config_file = ctx.actions.declare_file(name + "." + artifact.basename + ".config")
    manifest_file = ctx.actions.declare_file(name + "." + artifact.basename + ".manifest")
    args = ctx.actions.args()
    args.add("-imageTar", artifact)
    args.add("-outputConfig", config_file)
    args.add("-outputManifest", manifest_file)
    ctx.actions.run(
        executable = ctx.executable.extract_config,
        arguments = [args],
        tools = [artifact],
        outputs = [config_file, manifest_file],
        mnemonic = "ExtractConfig",
    )
    return {
        "config": config_file,
        # TODO(mattmoor): Do we need to compute config_digest here?
        # I believe we would for a checked in tarball to be usable
        # with docker_bundle + bazel run.
        "legacy": artifact,
        "manifest": manifest_file,
    }

def _file_path(ctx, val):
    """Return the path of the given file object.

    Args:
        ctx: The context.
        val: The file object.
    """
    return val.path

def generate_args_for_image(ctx, image, to_path = _file_path):
    """Generates arguments & inputs for the given image.

    Args:
        ctx: The context.
        image: The image parts dictionary as returned by 'get_from_target'.
        to_path: A function to transform the string paths as they
                        are added as arguments.

    Returns:
        The arguments to call the pusher, digester & flatenner with to load
        the given image.
        The file objects to define as inputs to the action.
    """
    compressed_layers = image.get("zipped_layer", [])
    uncompressed_layers = image.get("unzipped_layer", [])
    digest_files = image.get("blobsum", [])
    diff_id_files = image.get("diff_id", [])
    args = ["--config={}".format(to_path(ctx, image["config"]))]
    inputs = [image["config"]]
    inputs += compressed_layers
    inputs += uncompressed_layers
    inputs += digest_files
    inputs += diff_id_files
    for i, compressed_layer in enumerate(compressed_layers):
        uncompressed_layer = uncompressed_layers[i]
        digest_file = digest_files[i]
        diff_id_file = diff_id_files[i]
        args.append(
            "--layer={},{},{},{}".format(
                to_path(ctx, compressed_layer),
                to_path(ctx, uncompressed_layer),
                to_path(ctx, digest_file),
                to_path(ctx, diff_id_file),
            ),
        )
    if image.get("legacy"):
        inputs.append(image["legacy"])
        args.append("--tarball={}".format(to_path(ctx, image["legacy"])))
    if image["manifest"]:
        inputs.append(image["manifest"])
        args.append("--manifest={}".format(to_path(ctx, image["manifest"])))
    return args, inputs

def get_from_target(ctx, name, attr_target, file_target = None):
    """Gets all layers from the given target.

    Args:
       ctx: The context
       name: The name of the target
       attr_target: The attribute to get layers from
       file_target: If not None, layers are extracted from this target

    Returns:
       The extracted layers
    """
    if file_target:
        return _extract_layers(ctx, name, file_target)
    elif attr_target and ImageInfo in attr_target:
        return attr_target[ImageInfo].container_parts
    elif attr_target and ImportInfo in attr_target:
        return attr_target[ImportInfo].container_parts
    else:
        if not hasattr(attr_target, "files"):
            return {}
        target = attr_target.files.to_list()[0]
        return _extract_layers(ctx, name, target)

def _add_join_layers_args(args, inputs, images):
    """Add args & inputs needed to call the Go join_layers for the given images
    """
    for tag in images:
        image = images[tag]
        args.add(image["config"], format = "--tag=" + tag + "=%s")
        inputs.append(image["config"])

        if image.get("manifest"):
            args.add(image["manifest"], format = "--basemanifest=" + tag + "=%s")
            inputs.append(image["manifest"])

        for i in range(0, len(image["diff_id"])):
            # There's no way to do this with attrs w/o resolving paths here afaik
            args.add(
                "--layer={},{},{},{}".format(
                    image["zipped_layer"][i].path,
                    image["unzipped_layer"][i].path,
                    image["blobsum"][i].path,
                    image["diff_id"][i].path,
                ),
            )
        inputs += image["diff_id"]
        inputs += image["zipped_layer"]
        inputs += image["unzipped_layer"]
        inputs += image["blobsum"]

        if image.get("legacy"):
            args.add("--tarball", image["legacy"])
            inputs.append(image["legacy"])

def assemble(
        ctx,
        images,
        output,
        experimental_tarball_format,
        stamp = False):
    """Create the full image from the list of layers.

    Args:
       ctx: The context
       images: List of images/layers to assemple
       output: The output path for the image tar
       experimental_tarball_format: The format of the image tarball: "legacy" | "compressed"
       stamp: Whether to stamp the produced image
    """
    args = ctx.actions.args()
    args.add(output, format = "--output=%s")
    args.add(experimental_tarball_format, format = "--experimental-tarball-format=%s")
    inputs = []
    if stamp:
        args.add_all([ctx.info_file, ctx.version_file], format_each = "--stamp-info-file=%s")
        inputs += [ctx.info_file, ctx.version_file]
    _add_join_layers_args(args, inputs, images)

    ctx.actions.run(
        executable = ctx.executable._join_layers,
        arguments = [args],
        tools = inputs,
        outputs = [output],
        mnemonic = "JoinLayers",
    )

def incremental_load(
        ctx,
        images,
        output,
        stamp = False,
        run = False,
        run_flags = None):
    """Generate the incremental load statement.


    Args:
       ctx: The context
       images: List of images/layers to load
       output: The output path for the load script
       stamp: Whether to stamp the produced image
       run: Whether to run the script or not
       run_flags: Additional run flags
    """
    stamp_files = []
    if stamp:
        stamp_files = [ctx.info_file, ctx.version_file]

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    if run:
        if len(images) != 1:
            fail("Bazel run currently only supports the execution of a single " +
                 "container. Only loading multiple containers is supported")

        # Default to interactively launching the container, and cleaning up when
        # it exits. These template variables are unused if "run" is not set, so
        # it is harmless to always define them as a function of the first image.
        run_flags = run_flags or "-i --rm"
        run_statement = "\"${DOCKER}\" ${DOCKER_FLAGS} run %s" % run_flags
        run_tag = images.keys()[0]
        if stamp:
            run_tag = run_tag.replace("{", "${")
    else:
        run_statement = ""
        run_tag = ""

    load_statements = []
    tag_statements = []

    # TODO(mattmoor): Consider adding cleanup_statements.
    for tag in images:
        image = images[tag]

        # First load the legacy base image, if it exists.
        if image.get("legacy"):
            load_statements.append(
                "load_legacy '%s'" % _get_runfile_path(ctx, image["legacy"]),
            )

        pairs = zip(image["diff_id"], image["unzipped_layer"])

        # Import the config and the subset of layers not present
        # in the daemon.
        load_statements.append(
            "import_config '%s' %s" % (
                _get_runfile_path(ctx, image["config"]),
                " ".join([
                    "'%s' '%s'" % (
                        _get_runfile_path(ctx, diff_id),
                        _get_runfile_path(ctx, unzipped_layer),
                    )
                    for (diff_id, unzipped_layer) in pairs
                ]),
            ),
        )

        # Now tag the imported config with the specified tag.
        tag_reference = tag if not stamp else tag.replace("{", "${")
        tag_statements.append(
            "tag_layer \"%s\" '%s'" % (
                # Turn stamp variable references into bash variables.
                # It is notable that the only legal use of '{' in a
                # tag would be for stamp variables, '$' is not allowed.
                tag_reference,
                _get_runfile_path(ctx, image["config_digest"]),
            ),
        )

    ctx.actions.expand_template(
        template = ctx.file.incremental_load_template,
        substitutions = {
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
            "%{load_statements}": "\n".join(load_statements),
            "%{run_statement}": run_statement,
            "%{run_tag}": run_tag,
            "%{run}": str(run),
            # If this rule involves stamp variables than load them as bash
            # variables, and turn references to them into bash variable
            # references.
            "%{stamp_statements}": "\n".join([
                "read_variables %s" % _get_runfile_path(ctx, f)
                for f in stamp_files
            ]),
            "%{tag_statements}": "\n".join(tag_statements),
        },
        output = output,
        is_executable = True,
    )

tools = {
    "extract_config": attr.label(
        default = Label("//container/go/cmd/extract_config:extract_config"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "incremental_load_template": attr.label(
        default = Label("//container:incremental_load_template"),
        allow_single_file = True,
    ),
    "_join_layers": attr.label(
        default = Label("//container/go/cmd/join_layers"),
        cfg = "host",
        executable = True,
    ),
}
