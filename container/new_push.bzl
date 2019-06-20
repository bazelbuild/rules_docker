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
    "//skylib:path.bzl",
    "runfile",
)

def _get_runfile_path(ctx, f):
    return "${RUNFILES}/%s" % runfile(ctx, f)

def _impl(ctx):
    """Core implementation of new_container_push."""

    # TODO (xiaohegong): Possible optimization for efficiently pushing intermediate
    # representation, similar with the old python implementation, e.g., push-by-layer.
    # Some of the arguments omitted from before: --tarball, --config, --manifest, --digest, --layer, --oci.

    # TODO (xiaohegong): The old implementation outputs a {image_name}.digest for compatibility with container_digest, omitted for now.
    # ctx.actions.run(
    #     inputs = image_files,
    #     outputs = [ctx.outputs.digest],
    #     executable = ctx.executable._digester,
    #     arguments = [digester_args],
    #     tools = ctx.attr._digester[DefaultInfo].default_runfiles.files,
    #     mnemonic = "ContainerPushDigest",
    # )

    # NOTE: Implementation of attr.tag_file, docker toolchain custom client config and attr.stamp are omitted for now

    pusher_args = []
    digester_args = ctx.actions.args()

    # create pusher launcher
    registry = ctx.expand_make_variables("registry", ctx.attr.registry, {})
    repository = ctx.expand_make_variables("repository", ctx.attr.repository, {})
    tag = ctx.expand_make_variables("tag", ctx.attr.tag, {})

    pusher_args += ["-dst", "{registry}/{repository}:{tag}".format(
        registry = registry,
        repository = repository,
        tag = tag,
    )]

    for f in ctx.files.image:
      if f.basename == "index.json":
        pusher_args += ["-src", "{index_dir}".format(
        index_dir = f.dirname,
        )]
        break
    print(pusher_args)
    # print(ctx.files.image.path)

    ctx.actions.expand_template(
        template = ctx.file._tag_tpl,
        substitutions = {
            "%{args}": " ".join(pusher_args),
            "%{container_pusher}": _get_runfile_path(ctx, ctx.executable._pusher),
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [ctx.executable._pusher])
    runfiles = runfiles.merge(ctx.attr._pusher[DefaultInfo].default_runfiles)

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
            # values = [
            #     "OCI",
            #     "Docker",
            # ],
            doc = "The form to push: Docker or OCI.",
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
            # default = Label("@go_pusher//file:downloaded"),
            default = Label("@pusher//:pusher"),
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
    # outputs = {
    #     "digest": "%{name}.digest",
    # },
)
