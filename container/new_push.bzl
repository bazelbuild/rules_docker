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
"""An new implementation of container_push based on google/containerregistry using google/go-containerregistry.

This wraps the rules_docker.container.go.cmd.pusher.pusher executable in a
Bazel rule for publishing images.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@io_bazel_rules_docker//container:providers.bzl", "PushInfo")
load(
    "//container:layer_tools.bzl",
    _get_layers = "get_from_target",
    _layer_tools = "tools",
)
load(
    "//container:utils.bzl",
    "generate_legacy_dir",
)
load(
    "//skylib:path.bzl",
    "runfile",
)

def _get_runfile_path(ctx, f):
    return "${RUNFILES}/%s" % runfile(ctx, f)

def _impl(ctx):
    """Core implementation of new_container_push."""

    # TODO (xiaohegong): 1) Possible optimization for efficiently pushing intermediate
    # representation, similar with the old python implementation, e.g., push-by-layer.
    # Some of the digester arguments omitted from before: --tarball, --config, --manifest, --digest, --layer, --oci.
    # 2) The old implementation outputs a {image_name}.digest for compatibility with container_digest, omitted for now.
    # 3) Use and implementation of attr.stamp.

    pusher_args = []

    # Parse and get destination registry to be pushed to
    registry = ctx.expand_make_variables("registry", ctx.attr.registry, {})
    repository = ctx.expand_make_variables("repository", ctx.attr.repository, {})
    tag = ctx.expand_make_variables("tag", ctx.attr.tag, {})

    # If a tag file is provided, override <tag> with tag value
    runfiles_tag_file = []
    if ctx.file.tag_file:
        tag = "$(cat {})".format(_get_runfile_path(ctx, ctx.file.tag_file))
        runfiles_tag_file = [ctx.file.tag_file]

    pusher_args += ["-dst", "{registry}/{repository}:{tag}".format(
        registry = registry,
        repository = repository,
        tag = tag,
    )]

    # Find and set src to correct paths depending the image format to be pushed
    if ctx.attr.format == "oci":
        found = False
        for f in ctx.files.image:
            if f.basename == "index.json":
                pusher_args += ["-src", "{index_dir}".format(
                    index_dir = _get_runfile_path(ctx, f),
                )]
                found = True
        if not found:
            fail("Did not find an index.json in the image attribute {} specified to {}".format(ctx.attr.image, ctx.label))
    if ctx.attr.format == "docker":
        if len(ctx.files.image) == 0:
            fail("Attribute image {} to {} did not contain an image tarball".format(ctx.attr.image, ctx.label))
        if len(ctx.files.image) > 1:
            fail("Attribute image {} to {} had {} files. Expected exactly 1".format(ctx.attr.image, ctx.label, len(ctx.files.image)))
        pusher_args += ["-src", _get_runfile_path(ctx, ctx.files.image[0])]
    if ctx.attr.format == "legacy":
        legacy_dir = generate_legacy_dir(ctx)
        temp_files, config = legacy_dir["temp_files"], legacy_dir["config"]

        pusher_args += ["-src", "{}".format(_get_runfile_path(ctx, config))]

        for layer_path in legacy_dir["layers"]:
            pusher_args += ["-layers", "{}".format(_get_runfile_path(ctx, layer_path))]

    pusher_args += ["-format", str(ctx.attr.format)]

    # If the docker toolchain is configured to use a custom client config
    # directory, use that instead
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    if toolchain_info.client_config != "":
        pusher_args += ["-client-config-dir", str(toolchain_info.client_config)]

    pusher_runfiles = [ctx.executable._pusher] + runfiles_tag_file
    if ctx.attr.format == "legacy":
        pusher_runfiles += temp_files
    else:
        pusher_runfiles += ctx.files.image
    runfiles = ctx.runfiles(files = pusher_runfiles)
    runfiles = runfiles.merge(ctx.attr._pusher[DefaultInfo].default_runfiles)

    ctx.actions.expand_template(
        template = ctx.file._tag_tpl,
        substitutions = {
            "%{args}": " ".join(pusher_args),
            "%{container_pusher}": _get_runfile_path(ctx, ctx.executable._pusher),
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = ctx.outputs.executable,
            runfiles = runfiles,
        ),
        PushInfo(
            registry = registry,
            repository = repository,
            tag = tag,
        ),
    ]

# Pushes a container image to a registry.
new_container_push = rule(
    attrs = dicts.add({
        "format": attr.string(
            default = "oci",
            values = [
                "oci",
                "docker",
                "legacy",
            ],
            doc = "The form to push: docker, legacy or oci, default to 'oci'.",
        ),
        "image": attr.label(
            allow_files = True,
            mandatory = True,
            doc = "The label of the image to push.",
        ),
        "registry": attr.string(
            mandatory = True,
            doc = "The registry to which we are pushing.",
        ),
        "repository": attr.string(
            mandatory = True,
            doc = "The name of the image.",
        ),
        "stamp": attr.bool(
            default = False,
            mandatory = False,
        ),
        "tag": attr.string(
            default = "latest",
            doc = "(optional) The tag of the image, default to 'latest'.",
        ),
        "tag_file": attr.label(
            allow_single_file = True,
            doc = "(optional) The label of the file with tag value. Overrides 'tag'.",
        ),
        "_digester": attr.label(
            default = "@containerregistry//:digester",
            cfg = "host",
            executable = True,
        ),
        "_pusher": attr.label(
            default = Label("@io_bazel_rules_docker//container/go/cmd/pusher:pusher"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
        "_tag_tpl": attr.label(
            default = Label("//container:push-tag.sh.tpl"),
            allow_single_file = True,
        ),
    }, _layer_tools),
    executable = True,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _impl,
)
