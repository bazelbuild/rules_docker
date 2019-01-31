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
"""An implementation of container_push based on google/containerregistry.

This variant of container_push accepts a container_bundle target and publishes
the embedded image references.
"""

load(
    "//skylib:path.bzl",
    "runfile",
)

def _get_runfile_path(ctx, f):
    return "${RUNFILES}/%s" % runfile(ctx, f)

def _impl(ctx):
    """Core implementation of container_push."""
    stamp = ctx.attr.bundle.stamp
    images = ctx.attr.bundle.container_images

    stamp_inputs = []
    if stamp:
        stamp_inputs = [ctx.info_file, ctx.version_file]

    stamp_arg = " ".join(["--stamp-info-file=%s" % _get_runfile_path(ctx, f) for f in stamp_inputs])

    scripts = []
    runfiles = []
    for index, tag in enumerate(images.keys()):
        image = images[tag]

        # Leverage our efficient intermediate representation to push.
        legacy_base_arg = ""
        if image.get("legacy"):
            print("Pushing an image based on a tarball can be very " +
                  "expensive.  If the image is the output of a " +
                  "docker_build, consider dropping the '.tar' extension. " +
                  "If the image is checked in, consider using " +
                  "docker_import instead.")
            legacy_base_arg = "--tarball=%s" % _get_runfile_path(ctx, image["legacy"])
            runfiles += [image["legacy"]]

        blobsums = image.get("blobsum", [])
        digest_arg = " ".join(["--digest=%s" % _get_runfile_path(ctx, f) for f in blobsums])
        blobs = image.get("zipped_layer", [])
        layer_arg = " ".join(["--layer=%s" % _get_runfile_path(ctx, f) for f in blobs])
        config_arg = "--config=%s" % _get_runfile_path(ctx, image["config"])

        runfiles += [image["config"]] + blobsums + blobs

        out = ctx.actions.declare_file("%s.%d.push" % (ctx.label.name, index))
        ctx.actions.expand_template(
            template = ctx.file._tag_tpl,
            substitutions = {
                "%{args}": "%s --name=%s %s %s %s %s %s" % (
                    "--oci" if ctx.attr.format == "OCI" else "",
                    ctx.expand_make_variables("tag", tag, {}),
                    stamp_arg,
                    legacy_base_arg,
                    config_arg,
                    digest_arg,
                    layer_arg,
                ),
                "%{container_pusher}": _get_runfile_path(ctx, ctx.executable._pusher),
            },
            output = out,
            is_executable = True,
        )

        scripts += [out]
        runfiles += [out]

    ctx.actions.expand_template(
        template = ctx.file._all_tpl,
        substitutions = {
            "%{push_statements}": "\n".join([
                "async \"%s\"" % _get_runfile_path(ctx, command)
                for command in scripts
            ]),
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )

    return struct(runfiles = ctx.runfiles(files = [
        ctx.executable._pusher,
    ] + stamp_inputs + runfiles + ctx.attr._pusher.default_runfiles.files.to_list()))

container_push = rule(
    attrs = {
        "bundle": attr.label(
            mandatory = True,
            doc = "The bundle of tagged images to publish.",
        ),
        "format": attr.string(
            mandatory = True,
            values = [
                "OCI",
                "Docker",
            ],
            doc = "The form to push: Docker or OCI.",
        ),
        "_all_tpl": attr.label(
            default = Label("//contrib:push-all.sh.tpl"),
            allow_single_file = True,
        ),
        "_pusher": attr.label(
            default = Label("@containerregistry//:pusher"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
        "_tag_tpl": attr.label(
            default = Label("//container:push-tag.sh.tpl"),
            allow_single_file = True,
        ),
    },
    executable = True,
    implementation = _impl,
)

# Pushes a bundle of container images.
def docker_push(*args, **kwargs):
    if "format" in kwargs:
        fail(
            "Cannot override 'format' attribute on docker_push",
            attr = "format",
        )
    kwargs["format"] = "Docker"
    container_push(*args, **kwargs)

def oci_push(*args, **kwargs):
    if "format" in kwargs:
        fail(
            "Cannot override 'format' attribute on oci_push",
            attr = "format",
        )
    kwargs["format"] = "OCI"
    container_push(*args, **kwargs)
