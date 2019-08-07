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

This wraps the containerregistry.tools.fast_pusher executable in a
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
    """Core implementation of container_push."""
    pusher_args = []
    digester_args = ctx.actions.args()

    # Leverage our efficient intermediate representation to push.
    image = _get_layers(ctx, ctx.label.name, ctx.attr.image)
    blobsums = image.get("blobsum", [])
    blobs = image.get("zipped_layer", [])
    config = image["config"]
    manifest = image["manifest"]
    tarball = image.get("legacy")
    image_files = blobs + blobsums

    if tarball:
        print("Pushing an image based on a tarball can be very " +
              "expensive.  If the image is the output of a " +
              "docker_build, consider dropping the '.tar' extension. " +
              "If the image is checked in, consider using " +
              "docker_import instead.")
        pusher_args += ["--tarball=%s" % _get_runfile_path(ctx, tarball)]
        digester_args.add("--tarball", tarball)
        image_files += [tarball]
    if config:
        pusher_args += ["--config=%s" % _get_runfile_path(ctx, config)]
        digester_args.add("--config", config)
        image_files += [config]
    if manifest:
        pusher_args += ["--manifest=%s" % _get_runfile_path(ctx, manifest)]
        digester_args.add("--manifest", manifest)
        image_files += [manifest]
    for f in blobsums:
        pusher_args += ["--digest=%s" % _get_runfile_path(ctx, f)]
        digester_args.add("--digest", f)
    for f in blobs:
        pusher_args += ["--layer=%s" % _get_runfile_path(ctx, f)]
        digester_args.add("--layer", f)
    if ctx.attr.format == "OCI":
        pusher_args += ["--oci"]
        digester_args.add("--oci")

    # create image digest
    digester_args.add("--output-digest", ctx.outputs.digest)
    ctx.actions.run(
        inputs = image_files,
        outputs = [ctx.outputs.digest],
        executable = ctx.executable._digester,
        arguments = [digester_args],
        tools = ctx.attr._digester[DefaultInfo].default_runfiles.files,
        mnemonic = "ContainerPushDigest",
    )

    # create pusher launcher
    registry = ctx.expand_make_variables("registry", ctx.attr.registry, {})
    repository = ctx.expand_make_variables("repository", ctx.attr.repository, {})
    tag = ctx.expand_make_variables("tag", ctx.attr.tag, {})
    runfiles_tag_file = []
    if ctx.file.tag_file:
        tag = "$(cat {})".format(_get_runfile_path(ctx, ctx.file.tag_file))
        runfiles_tag_file = [ctx.file.tag_file]
    if ctx.attr.stamp:
        print("Attr 'stamp' is deprecated; it is now automatically inferred. Please remove it from %s" % ctx.label)

    # If any stampable attr contains python format syntax (which is how users
    # configure stamping), we enable stamping.
    stamp = "{" in tag or "{" in registry or "{" in repository
    stamp_inputs = [ctx.info_file, ctx.version_file] if stamp else []
    pusher_args += [" ".join(["--stamp-info-file=%s" % _get_runfile_path(ctx, f) for f in stamp_inputs])]
    pusher_args += ["--name={registry}/{repository}:{tag}".format(
        registry = registry,
        repository = repository,
        tag = tag,
    )]

    # If the docker toolchain is configured to use a custom client config
    # directory, use that instead
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    if toolchain_info.client_config != "":
        pusher_args += [" --client-config-dir {}".format(toolchain_info.client_config)]

    ctx.actions.expand_template(
        template = ctx.file._tag_tpl,
        substitutions = {
            "%{args}": " ".join(pusher_args),
            "%{container_pusher}": _get_runfile_path(ctx, ctx.executable._pusher),
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [ctx.executable._pusher] + image_files + stamp_inputs + runfiles_tag_file)
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
            stamp = stamp,
            stamp_inputs = stamp_inputs,
            digest = ctx.outputs.digest,
        ),
    ]

# Pushes a container image to a registry.
container_push = rule(
    attrs = dicts.add({
        "format": attr.string(
            mandatory = True,
            values = [
                "OCI",
                "Docker",
            ],
            doc = "The form to push: Docker or OCI.",
        ),
        "image": attr.label(
            allow_single_file = [".tar"],
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
            default = Label("@containerregistry//:pusher"),
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
    outputs = {
        "digest": "%{name}.digest",
    },
)
