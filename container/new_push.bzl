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

    # TODO (xiaohegong): 1) Possible optimization for efficiently pushing intermediate
    # representation, similar with the old python implementation, e.g., push-by-layer.
    # Some of the digester arguments omitted from before: --tarball, --config, --manifest, --digest, --layer, --oci.
    # 2) The old implementation outputs a {image_name}.digest for compatibility with container_digest, omitted for now.
    # 3) Use and implementation of attr.stamp.

    pusher_args = []
    # digester_args = ctx.actions.args()

    # Leverage our efficient intermediate representation to push.
    image = _get_layers(ctx, ctx.label.name, ctx.attr.image)
    blobsums = []
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
        # pusher_args += ["--tarball=%s" % _get_runfile_path(ctx, tarball)]
        # digester_args.add("--tarball", tarball)
        image_files += [tarball]
    if config:
        # pusher_args += ["--config=%s" % _get_runfile_path(ctx, config)]
        # digester_args.add("--config", config)
        image_files += [config]
    if manifest:
        # pusher_args += ["--manifest=%s" % _get_runfile_path(ctx, manifest)]
        # digester_args.add("--manifest", manifest)
        image_files += [manifest]
    # for f in blobsums:
        # pusher_args += ["--digest=%s" % _get_runfile_path(ctx, f)]
        # digester_args.add("--digest", f)
    # for f in blobs:
        # pusher_args += ["--layer=%s" % _get_runfile_path(ctx, f)]
        # digester_args.add("--layer", f)

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
    if ctx.attr.format == "legacy":
        for f in ctx.files.image:
            if f.basename == "manifest.json":
                pusher_args += ["-src", "{index_dir}".format(
                    index_dir = _get_runfile_path(ctx, f),
                )]
    if ctx.attr.format == "docker":
        if len(ctx.files.image) == 0:
            fail("Attribute image {} to {} did not contain an image tarball".format(ctx.attr.image, ctx.label))
        if len(ctx.files.image) > 1:
            fail("Attribute image {} to {} had {} files. Expected exactly 1".format(ctx.attr.image, ctx.label, len(ctx.files.image)))
        pusher_args += ["-src", _get_runfile_path(ctx, ctx.files.image[0])]

    pusher_args += ["-format", str(ctx.attr.format)]

    # If the docker toolchain is configured to use a custom client config
    # directory, use that instead
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    if toolchain_info.client_config != "":
        pusher_args += ["-client-config-dir", str(toolchain_info.client_config)]

    ctx.actions.expand_template(
        template = ctx.file._tag_tpl,
        substitutions = {
            "%{args}": " ".join(pusher_args),
            "%{container_pusher}": _get_runfile_path(ctx, ctx.executable._pusher),
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )

    temp_files = []
    counter = 0
    for i in image_files:
        if ".tar.gz" in f.basename:
            out_files = ctx.actions.declare_file("image_files/" + "00" + str(counter) + ".tar.gz")
            counter += 1
        elif "config" in f.basename:
            out_files = ctx.actions.declare_file("image_files/" + "config.json")
        elif "manifest" in f.basename:
            out_files = ctx.actions.declare_file("image_files/" + "manifest.json")
        temp_files.append(out_files)
        ctx.actions.run_shell(
        outputs = [out_files],
        inputs = [f],
        command = "ln {src} {dst}".format(
            src = f.path,
            dst = out_files.path,
        ),
        )

    runfiles = ctx.runfiles(files = [ctx.executable._pusher] + image_files +
                                    runfiles_tag_file + ctx.files.image + temp_files)
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
            default = "oci",
            values = [
                "oci",
                "docker",
                "legacy",
            ],
            doc = "The form to push: docker or oci, default to 'oci'.",
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
