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
    "//skylib:path.bzl",
    _get_runfile_path = "runfile",
)

def _extract_layers(ctx, name, artifact):
    config_file = ctx.new_file(name + "." + artifact.basename + ".config")
    manifest_file = ctx.new_file(name + "." + artifact.basename + ".manifest")
    ctx.action(
        executable = ctx.executable.extract_config,
        arguments = [
            "--tarball",
            artifact.path,
            "--output",
            config_file.path,
            "--manifestoutput",
            manifest_file.path,
        ],
        inputs = [artifact],
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
    if file_target:
        return _extract_layers(ctx, name, file_target)
    elif hasattr(attr_target, "container_parts"):
        return attr_target.container_parts
    else:
        if not hasattr(attr_target, "files"):
            return {}
        target = attr_target.files.to_list()[0]
        return _extract_layers(ctx, name, target)

def assemble(ctx, images, output, stamp = False):
    """Create the full image from the list of layers."""
    args = [
        "--output=" + output.path,
    ]

    inputs = []
    for tag in images:
        image = images[tag]
        args += [
            "--tags=" + tag + "=@" + image["config"].path,
        ]

        if image.get("manifest"):
            args += [
                "--manifests=" + tag + "=@" + image["manifest"].path,
            ]

        inputs += [image["config"]]

        if image.get("manifest"):
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

    if stamp:
        args += ["--stamp-info-file=%s" % f.path for f in (ctx.info_file, ctx.version_file)]
        inputs += [ctx.info_file, ctx.version_file]
    ctx.action(
        executable = ctx.executable.join_layers,
        arguments = args,
        inputs = inputs,
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
    """Generate the incremental load statement."""
    stamp_files = []
    if stamp:
        stamp_files = [ctx.info_file, ctx.version_file]

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
            # bazel automatically passes ctx.attr.args to the binary on run, so args get passed in
            # twice. See https://github.com/bazelbuild/rules_docker/issues/374
            run_statements += [
                "docker run %s %s \"$@\"" % (run_flags, tag_reference),
            ]

    ctx.template_action(
        template = ctx.file.incremental_load_template,
        substitutions = {
            # If this rule involves stamp variables than load them as bash
            # variables, and turn references to them into bash variable
            # references.
            "%{stamp_statements}": "\n".join([
                "read_variables %s" % _get_runfile_path(ctx, f)
                for f in stamp_files
            ]),
            "%{load_statements}": "\n".join(load_statements),
            "%{tag_statements}": "\n".join(tag_statements),
            "%{run_statements}": "\n".join(run_statements),
        },
        output = output,
        executable = True,
    )

tools = {
    "incremental_load_template": attr.label(
        default = Label("//container:incremental_load_template"),
        single_file = True,
        allow_files = True,
    ),
    "join_layers": attr.label(
        default = Label("//container:join_layers"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "extract_config": attr.label(
        default = Label("//container:extract_config"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}
