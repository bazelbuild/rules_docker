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

load("@io_bazel_rules_docker//container:providers.bzl", "BundleInfo")
load(
    "//container:layer_tools.bzl",
    _gen_img_args = "generate_args_for_image",
)
load(
    "//skylib:path.bzl",
    "runfile",
)

def _get_runfile_path(ctx, f):
    return "${RUNFILES}/%s" % runfile(ctx, f)

def _impl(ctx):
    """Core implementation of container_push."""
    stamp = ctx.attr.bundle[BundleInfo].stamp
    images = ctx.attr.bundle[BundleInfo].container_images

    stamp_inputs = []
    if stamp:
        stamp_inputs = [ctx.info_file, ctx.version_file]

    scripts = []
    runfiles = []
    for index, tag in enumerate(images.keys()):
        image = images[tag]

        pusher_args, pusher_inputs = _gen_img_args(ctx, image, _get_runfile_path)
        pusher_args += ["--stamp-info-file=%s" % _get_runfile_path(ctx, f) for f in stamp_inputs]
        if ctx.attr.skip_unchanged_digest:
            pusher_args.append("--skip-unchanged-digest")
        pusher_args.append("--dst={}".format(tag))
        pusher_args.append("--format={}".format(ctx.attr.format))

        # If the docker toolchain is configured to use a custom client config
        # directory, use that instead
        toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
        if toolchain_info.client_config != "":
            pusher_args += ["-client-config-dir", str(toolchain_info.client_config)]

        out = ctx.actions.declare_file("%s.%d.push" % (ctx.label.name, index))
        ctx.actions.expand_template(
            template = ctx.file._tag_tpl,
            substitutions = {
                "%{args}": " ".join(pusher_args),
                "%{container_pusher}": _get_runfile_path(ctx, ctx.executable._pusher),
            },
            output = out,
            is_executable = True,
        )

        scripts.append(out)
        runfiles.append(out)
        runfiles += pusher_inputs

    ctx.actions.expand_template(
        template = ctx.file._all_tpl,
        substitutions = {
            "%{async_push_statements}": "\n".join([
                "async \"%s\"" % _get_runfile_path(ctx, command)
                for command in scripts
            ]),
            "%{push_statements}": "\n".join([
                "\"%s\"" % _get_runfile_path(ctx, command)
                for command in scripts
            ]),
            "%{sequential}": "true" if ctx.attr.sequential else "",
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = [ctx.executable._pusher] + stamp_inputs + runfiles,
                transitive_files = ctx.attr._pusher[DefaultInfo].default_runfiles.files,
            ),
        ),
    ]

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
        "sequential": attr.bool(
            default = False,
            doc = "If true, push images sequentially.",
        ),
        "skip_unchanged_digest": attr.bool(
            default = False,
            doc = "Only push images if the digest has changed, default to False",
        ),
        "_all_tpl": attr.label(
            default = Label("//contrib:push-all.sh.tpl"),
            allow_single_file = True,
        ),
        "_pusher": attr.label(
            default = Label("//container/go/cmd/pusher"),
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
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
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
