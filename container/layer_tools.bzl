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

def _extract_layers(ctx, name, artifact):
    config_file = ctx.actions.declare_file(name + "." + artifact.basename + ".config")
    manifest_file = ctx.actions.declare_file(name + "." + artifact.basename + ".manifest")
    ctx.actions.run(
        executable = ctx.executable.extract_config,
        arguments = [
            "-imageTar",
            artifact.path,
            "-outputConfig",
            config_file.path,
            "-outputManifest",
            manifest_file.path,
        ],
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

def _add_join_layers_py_args(args, inputs, images):
    """Add args & inputs needed to call join_layers.py for the given images
    """
    for tag in images:
        image = images[tag]
        args += [
            "--tags=" + tag + "=@" + image["config"].path,
        ]
        inputs += [image["config"]]

        if image.get("manifest"):
            args += [
                "--manifests=" + tag + "=@" + image["manifest"].path,
            ]
            inputs += [image["manifest"]]

        for i in range(0, len(image["diff_id"])):
            args += [
                "--layer=" +
                "@" + image["diff_id"][i].path +
                "=@" + image["blobsum"][i].path +
                # No @, not resolved through utils, always filename.
                "=" + image["unzipped_layer"][i].path +
                "=" + image["zipped_layer"][i].path,
            ]
        inputs += image["unzipped_layer"]
        inputs += image["diff_id"]
        inputs += image["zipped_layer"]
        inputs += image["blobsum"]

        if image.get("legacy"):
            args += ["--legacy=" + image["legacy"].path]
            inputs += [image["legacy"]]

def _add_join_layers_go_args(args, inputs, images):
    """Add args & inputs needed to call the Go join_layers for the given images
    """
    for tag in images:
        image = images[tag]
        args += [
            "--tag=" + tag + "=" + image["config"].path,
        ]
        inputs += [image["config"]]

        if image.get("manifest"):
            args += [
                "--basemanifest=" + tag + "=" + image["manifest"].path,
            ]
            inputs += [image["manifest"]]

        for i in range(0, len(image["diff_id"])):
            args += [
                "--layer=" +
                image["diff_id"][i].path +
                "," + image["blobsum"][i].path +
                "," + image["zipped_layer"][i].path,
            ]
        inputs += image["diff_id"]
        inputs += image["zipped_layer"]
        inputs += image["blobsum"]

        if image.get("legacy"):
            args += ["--source_image=" + image["legacy"].path]
            inputs += [image["legacy"]]

def assemble(
        ctx,
        images,
        output,
        stamp = False,
        use_py_join_layers = True):
    """Create the full image from the list of layers.

    Args:
       ctx: The context
       images: List of images/layers to assemple
       output: The output path for the image tar
       stamp: Whether to stamp the produced image
       use_py_join_layers: Whether to use the python join_layers. Uses the Go
                           join_layers when set to false.
    """
    args = [
        "--output=" + output.path,
    ]
    inputs = []
    if stamp:
        args += ["--stamp_info_file=%s" % f.path for f in (ctx.info_file, ctx.version_file)]
        inputs += [ctx.info_file, ctx.version_file]
    if use_py_join_layers:
        _add_join_layers_py_args(args, inputs, images)
    else:
        _add_join_layers_go_args(args, inputs, images)

    ctx.actions.run(
        executable = ctx.executable.join_layers_py if use_py_join_layers else ctx.executable.join_layers_go,
        arguments = args,
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

    # Default to interactively launching the container,
    # and cleaning up when it exits.

    run_flags = run_flags or "-i --rm"

    if len(images) > 1 and run:
        fail("Bazel run does not currently support execution of " +
             "multiple containers (only loading).")

    load_statements = []
    tag_statements = []
    run_statements = []

    # TODO(mattmoor): Consider adding cleanup_statements.
    for tag in images:
        image = images[tag]

        # First load the legacy base image, if it exists.
        if image.get("legacy"):
            load_statements += [
                "load_legacy '%s'" % _get_runfile_path(ctx, image["legacy"]),
            ]

        pairs = zip(image["diff_id"], image["unzipped_layer"])

        # Import the config and the subset of layers not present
        # in the daemon.
        load_statements += [
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
        ]

        # Now tag the imported config with the specified tag.
        tag_reference = tag if not stamp else tag.replace("{", "${")
        tag_statements += [
            "tag_layer \"%s\" '%s'" % (
                # Turn stamp variable references into bash variables.
                # It is notable that the only legal use of '{' in a
                # tag would be for stamp variables, '$' is not allowed.
                tag_reference,
                _get_runfile_path(ctx, image["config_digest"]),
            ),
        ]
        if run:
            # Args are embedded into the image, so omitted here.
            run_statements += [
                "\"${DOCKER}\" run %s %s" % (run_flags, tag_reference),
            ]

    ctx.actions.expand_template(
        template = ctx.file.incremental_load_template,
        substitutions = {
            "%{docker_tool_path}": toolchain_info.tool_path,
            "%{load_statements}": "\n".join(load_statements),
            "%{run_statements}": "\n".join(run_statements),
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
    "join_layers_go": attr.label(
        default = Label("//container/go/cmd/join_layers"),
        cfg = "host",
        executable = True,
    ),
    "join_layers_py": attr.label(
        default = Label("//container:join_layers"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "use_py_join_layers": attr.bool(
        default = True,
        doc = "Use the python join_layers.py to build the image tarball." +
              "Uses the Go implementation when set to false.",
    ),
}
