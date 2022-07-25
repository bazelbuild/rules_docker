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
"""An implementation of container_push based on google/go-containerregistry.
This wraps the rules_docker.container.go.cmd.pusher.pusher executable in a
Bazel rule for publishing images.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@io_bazel_rules_docker//container:providers.bzl", "PushInfo", "STAMP_ATTR", "StampSettingInfo")
load(
    "//container:layer_tools.bzl",
    _gen_img_args = "generate_args_for_image",
    _get_layers = "get_from_target",
    _layer_tools = "tools",
)
load(
    "//skylib:path.bzl",
    "runfile",
)

def _digester_run_action(ctx, image, output_file):
    args = [
        "--dst",
        output_file.path,
        "--format",
        ctx.attr.format,
    ]

    img_args, img_inputs = _gen_img_args(ctx, image)

    ctx.actions.run(
        inputs = img_inputs,
        outputs = [output_file],
        executable = ctx.executable._digester,
        arguments = args + img_args,
        tools = ctx.attr._digester[DefaultInfo].default_runfiles.files,
        mnemonic = "ContainerPushDigest",
    )

def _pusher_write_scripts_common(ctx, ii):
    args = []
    inputs = []

    # If the docker toolchain is configured to use a custom client config
    # directory, use that instead
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    if toolchain_info.client_config != "":
        args += ["-client-config-dir", toolchain_info.client_config]

    args.append("--format={}".format(ii.format))

    # Parse and get destination registry to be pushed to
    registry = ctx.expand_make_variables("registry", ii.registry, {})

    # If a repository file is provided, override <repository> with tag value
    if ii.repository_file:
        repository = "$(cat {})".format(_get_runfile_path(ctx, ii.repository_file))
        inputs.append(ii.repository_file)
    else:
        repository = ctx.expand_make_variables("repository", ii.repository, {})

    # If a tag file is provided, override <tag> with tag value
    if ii.tag_file:
        tag = "$(cat {})".format(_get_runfile_path(ctx, ii.tag_file))
        inputs.append(ii.tag_file)
    else:
        tag = ctx.expand_make_variables("tag", ii.tag, {})

    args.append("--dst={registry}/{repository}:{tag}".format(
        registry = registry,
        repository = repository,
        tag = tag,
    ))

    stamp_inputs = [ctx.info_file, ctx.version_file] if ii.stamp else []
    for f in stamp_inputs:
        args += ["-stamp-info-file", "%s" % _get_runfile_path(ctx, f)]
    inputs += stamp_inputs

    if ii.skip_unchanged_digest:
        args.append("-skip-unchanged-digest")
    if ii.insecure_repository:
        args.append("-insecure-repository")

    return args, inputs, struct(
        registry = registry,
        repository = repository,
    )

def _get_runfile_path(ctx, f):
    if ctx.attr.windows_paths:
        return "%RUNFILES%\\{}".format(runfile(ctx, f).replace("/", "\\"))
    else:
        return "${RUNFILES}/%s" % runfile(ctx, f)

def _pusher_write_script(ctx, image, ii, template_file, output_file):
    args, inputs, md = _pusher_write_scripts_common(ctx, ii)

    img_args, img_inputs = _gen_img_args(ctx, image, _get_runfile_path)
    args += img_args
    inputs += img_inputs

    ctx.actions.expand_template(
        template = template_file,
        output = output_file,
        substitutions = {
            "%{args}": " ".join(args),
            "%{container_pusher}": _get_runfile_path(ctx, ctx.executable._pusher),
        },
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [ctx.executable._pusher] + inputs)
    runfiles = runfiles.merge(ctx.attr._pusher[DefaultInfo].default_runfiles)

    return runfiles, md

def _get_image_from_target(ctx, target):
    image = _get_layers(ctx, ctx.label.name, target)
    if image.get("legacy"):
        # buildifier: disable=print
        print("Pushing an image based on a tarball can be very " +
              "expensive. If the image set on %s is the output of a " % ctx.label +
              "docker_build, consider dropping the '.tar' extension. " +
              "If the image is checked in, consider using " +
              "container_import instead.")

    return image

def _container_push_impl(ctx):
    """Core implementation of container_push."""

    # TODO: Possible optimization for efficiently pushing intermediate format after container_image is refactored, similar with the old python implementation, e.g., push-by-layer.

    image = _get_image_from_target(ctx, ctx.attr.image)

    exe = ctx.actions.declare_file(ctx.label.name + ctx.attr.extension)
    runfiles, md = _pusher_write_script(
        ctx,
        image,
        template_file = ctx.file.tag_tpl,
        output_file = exe,
        ii = struct(
            registry = ctx.attr.registry,
            repository = ctx.attr.repository,
            repository_file = ctx.file.repository_file,
            tag = ctx.attr.tag,
            tag_file = ctx.file.tag_file,
            stamp = ctx.attr.stamp[StampSettingInfo].value,
            format = ctx.attr.format,
            skip_unchanged_digest = ctx.attr.skip_unchanged_digest,
            insecure_repository = ctx.attr.insecure_repository,
        ),
    )

    _digester_run_action(ctx, image, ctx.outputs.digest)

    return [
        DefaultInfo(
            executable = exe,
            runfiles = runfiles,
        ),
        OutputGroupInfo(
            exe = [exe],
        ),
        PushInfo(
            registry = md.registry,
            repository = md.repository,
            digest = ctx.outputs.digest,
        ),
    ]

_container_push_common_attrs = dicts.add({
    "extension": attr.string(
        doc = "The file extension for the push script.",
    ),
    "format": attr.string(
        values = [
            "OCI",
            "Docker",
        ],
        mandatory = True,
        doc = "The form to push: Docker or OCI, default to 'Docker'.",
    ),
    "insecure_repository": attr.bool(
        default = False,
        doc = "Whether the repository is insecure or not (http vs https)",
    ),
    "registry": attr.string(
        mandatory = True,
        doc = "The registry to which we are pushing.",
    ),
    "repository": attr.string(
        mandatory = True,
        doc = "The name of the image.",
    ),
    "repository_file": attr.label(
        allow_single_file = True,
        doc = "The label of the file with repository value. Overrides 'repository'.",
    ),
    "skip_unchanged_digest": attr.bool(
        default = False,
        doc = "Check if the container registry already contain the image's digest. If yes, skip the push for that image. " +
              "Default to False. " +
              "Note that there is no transactional guarantee between checking for digest existence and pushing the digest. " +
              "This means that you should try to avoid running the same container_push targets in parallel.",
    ),
    "stamp": STAMP_ATTR,
    "tag": attr.string(
        default = "latest",
        doc = "The tag of the image.",
    ),
    "tag_file": attr.label(
        allow_single_file = True,
        doc = "The label of the file with tag value. Overrides 'tag'.",
    ),
    "tag_tpl": attr.label(
        mandatory = True,
        allow_single_file = True,
        doc = "The script template to use.",
    ),
    "windows_paths": attr.bool(
        mandatory = True,
    ),
}, _layer_tools)

container_push_ = rule(
    attrs = dicts.add(_container_push_common_attrs, {
        "image": attr.label(
            allow_single_file = [".tar"],
            mandatory = True,
            doc = "The label of the image to push.",
        ),
        "_digester": attr.label(
            default = "//container/go/cmd/digester",
            cfg = "exec",
            executable = True,
        ),
        "_pusher": attr.label(
            default = "//container/go/cmd/pusher",
            cfg = "exec",
            executable = True,
            allow_files = True,
        ),
    }),
    executable = True,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _container_push_impl,
    outputs = {
        "digest": "%{name}.digest",
    },
)

def _run_container_push_rule(f, **kwargs):
    kwargs.update({
        "extension": kwargs.pop("extension", select({
            "@bazel_tools//src/conditions:host_windows": ".bat",
            "//conditions:default": "",
        })),
        "tag_tpl": select({
            "@bazel_tools//src/conditions:host_windows": Label("//container:push-tag.bat.tpl"),
            "//conditions:default": Label("//container:push-tag.sh.tpl"),
        }),
        "windows_paths": select({
            "@bazel_tools//src/conditions:host_windows": True,
            "//conditions:default": False,
        }),
    })
    f(**kwargs)

def container_push(name, format, image, registry, repository, **kwargs):
    """Pushes a single container image to a registry."""
    _run_container_push_rule(
        container_push_,
        name = name,
        format = format,
        image = image,
        registry = registry,
        repository = repository,
        **kwargs
    )
