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

"""
Rules to run a command inside a container, and either commit the result
to new container image, or extract specified targets to a directory on
the host machine.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "//skylib:hash.bzl",
    _hash_tools = "tools",
)
load("@io_bazel_rules_docker//container:container.bzl", _container = "container")
load("@io_bazel_rules_docker//container:image.bzl", _image = "image")
load("@io_bazel_rules_docker//container:layer.bzl", "zip_layer")
load("@io_bazel_rules_docker//container:layer_tools.bzl", _get_layers = "get_from_target")
load("@io_bazel_rules_docker//container:providers.bzl", "ImageInfo", "LayerInfo")
load("//skylib:path.bzl", _join_path = "join")
load(
    "//skylib:zip.bzl",
    _zip_tools = "tools",
)
load(
    "//skylib:docker.bzl",
    "docker_path",
)

def _extract_impl(
        ctx,
        name = "",
        base = None,
        cmd = None,
        extract_file = "",
        output_file = "",
        script_file = "",
        extra_deps = None):
    """Implementation for the container_run_and_extract rule.

    This rule runs a set of commands in a given image, waits for the commands
    to finish, and then extracts a given file from the container to the
    bazel-out directory.

    Args:
        ctx: The bazel rule context
        name: String, overrides ctx.label.name
        base: File, overrides ctx.attr.base
        cmd: str List, overrides ctx.attr.cmd
        extract_file: File, overrides ctx.outputs.out
        output_file: File, overrides ctx.outputs.output_file
        script_file: File, overrides ctx.output.script_file
        extra_deps: Label list, if not None these are passed as inputs
                    to the action running the container. This can be used if
                    e.g., you need to mount a directory that is produced
                    by another action.
    """

    name = name or ctx.label.name
    extract_file = extract_file or ctx.attr.extract_file
    output_file = output_file or ctx.outputs.out
    script_file = script_file or ctx.outputs.script

    docker_run_flags = ""
    if ctx.attr.docker_run_flags != "":
        docker_run_flags = ctx.attr.docker_run_flags
    elif ctx.attr.base and ImageInfo in ctx.attr.base:
        docker_run_flags = ctx.attr.base[ImageInfo].docker_run_flags
    if "-d" not in docker_run_flags:
        docker_run_flags += " -d"

    run_image = "%s.run" % name
    run_image_output_executable = ctx.actions.declare_file("%s.executable" % run_image)
    run_image_output_tarball = ctx.actions.declare_file("%s.tar" % run_image)
    run_image_output_config = ctx.actions.declare_file("%s.json" % run_image)
    run_image_output_config_digest = ctx.actions.declare_file("%s.json.sha256" % run_image)
    run_image_output_digest = ctx.actions.declare_file("%s.digest" % run_image)
    run_image_output_layer = ctx.actions.declare_file("%s-layer.tar" % run_image)

    image_result = _image.implementation(
        ctx,
        name,
        base = base,
        cmd = cmd,
        output_executable = run_image_output_executable,
        output_tarball = run_image_output_tarball,
        output_config = run_image_output_config,
        output_config_digest = run_image_output_config_digest,
        output_digest = run_image_output_digest,
        output_layer = run_image_output_layer,
        action_run = True,
        docker_run_flags = docker_run_flags,
    )

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    footer = ctx.actions.declare_file(name + "_footer.sh")

    ctx.actions.expand_template(
        template = ctx.file._extract_tpl,
        output = footer,
        substitutions = {
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_run_flags}": docker_run_flags,
            "%{docker_tool_path}": docker_path(toolchain_info),
            "%{extract_file}": extract_file,
            "%{legacy_load_behavior}": "false",
            "%{output}": output_file.path,
        },
    )

    ctx.actions.run_shell(
        inputs = [run_image_output_executable, footer],
        outputs = [script_file],
        mnemonic = "Concat",
        command = """
            set -eu
            cat {first} {second} > {output}
        """.format(
            first = run_image_output_executable.path,
            second = footer.path,
            output = script_file.path,
        ),
    )

    ctx.actions.run(
        executable = script_file,
        tools = image_result[1].default_runfiles.files,
        outputs = [output_file],
        use_default_shell_env = True,
    )

    return [
        DefaultInfo(
            files = depset([script_file, output_file]),
        ),
    ]

_extract_attrs = dicts.add(_image.attrs, {
    "docker_run_flags": attr.string(
        doc = """Optional flags to use with `docker run` command.

        Only used when `legacy_run_behavior` is set to `False`.""",
    ),
    "extract_file": attr.string(
        doc = "Path to file to extract from container.",
        mandatory = True,
    ),
    "legacy_run_behavior": attr.bool(
        default = False,
    ),
    "_extract_tpl": attr.label(
        default = Label("//docker/util:extract.sh.tpl"),
        allow_single_file = True,
    ),
})

_extract_outputs = {
    "out": "%{name}%{extract_file}",
    "script": "%{name}.build",
}

container_run_and_extract_rule = rule(
    attrs = _extract_attrs,
    cfg = _container.image.cfg,
    doc = ("This rule runs a set of commands in a given image, waits" +
           "for the commands to finish, and then extracts a given file" +
           " from the container to the bazel-out directory."),
    outputs = _extract_outputs,
    implementation = _extract_impl,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def _extract_impl_legacy(
        ctx,
        name = "",
        image = None,
        commands = None,
        docker_run_flags = None,
        extract_file = "",
        output_file = "",
        script_file = "",
        extra_deps = None):
    """Legacy implementation for the container_run_and_extract rule.

    Args:
        ctx: The bazel rule context
        name: String, overrides ctx.label.name
        image: File, overrides ctx.file.image_tar
        commands: String list, overrides ctx.attr.commands
        docker_run_flags: String list, overrides ctx.attr.docker_run_flags
        extract_file: File, overrides ctx.outputs.out
        output_file: File, overrides ctx.outputs.output_file
        script_file: File, overrides ctx.output.script_file
        extra_deps: Label list, if not None these are passed as inputs
                    to the action running the container. This can be used if
                    e.g., you need to mount a directory that is produced
                    by another action.
    """
    name = name or ctx.label.name
    image = image or ctx.file.image
    commands = commands or ctx.attr.commands
    docker_run_flags = docker_run_flags or ctx.attr.docker_run_flags
    extract_file = extract_file or ctx.attr.extract_file
    output_file = output_file or ctx.outputs.out
    script = script_file or ctx.outputs.script
    extra_deps = extra_deps or ctx.files.extra_deps

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    # Generate a shell script to execute the run statement
    ctx.actions.expand_template(
        template = ctx.file._extract_tpl,
        output = script,
        substitutions = {
            "%{commands}": _process_commands(commands),
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_run_flags}": " ".join(docker_run_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
            "%{extract_file}": extract_file,
            "%{image_id_extractor_path}": ctx.executable._extract_image_id.path,
            "%{image_tar}": image.path,
            "%{legacy_load_behavior}": "true",
            "%{output}": output_file.path,
        },
        is_executable = True,
    )

    ctx.actions.run(
        inputs = extra_deps if extra_deps else [],
        outputs = [output_file],
        tools = [image, ctx.executable._extract_image_id],
        executable = script,
        use_default_shell_env = True,
    )

    return []

_extract_attrs_legacy = {
    "commands": attr.string_list(
        doc = "A list of commands to run (sequentially) in the container.",
        mandatory = True,
        allow_empty = False,
    ),
    "docker_run_flags": attr.string_list(
        doc = "Extra flags to pass to the docker run command.",
        mandatory = False,
    ),
    "extract_file": attr.string(
        doc = "Path to file to extract from container.",
        mandatory = True,
    ),
    "extra_deps": attr.label_list(
        doc = "Extra dependency to be passed as inputs",
        mandatory = False,
        allow_files = True,
    ),
    "image": attr.label(
        executable = True,
        doc = "The image to run the commands in.",
        mandatory = True,
        allow_single_file = True,
        cfg = "target",
    ),
    "_extract_image_id": attr.label(
        default = Label("//contrib:extract_image_id"),
        cfg = "exec",
        executable = True,
        allow_files = True,
    ),
    "_extract_tpl": attr.label(
        default = Label("//docker/util:extract.sh.tpl"),
        allow_single_file = True,
    ),
}

container_run_and_extract_legacy = rule(
    attrs = _extract_attrs_legacy,
    doc = ("This rule runs a set of commands in a given image, waits" +
           "for the commands to finish, and then extracts a given file" +
           " from the container to the bazel-out directory."),
    outputs = _extract_outputs,
    implementation = _extract_impl_legacy,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def container_run_and_extract(name, legacy_load_behavior = True, **kwargs):
    if legacy_load_behavior:
        container_run_and_extract_legacy(
            name = name,
            **kwargs
        )
    else:
        container_run_and_extract_rule(
            name = name,
            **kwargs
        )

# Export container_run_and_extract rule for other bazel rules to depend on.
extract = struct(
    attrs = _extract_attrs_legacy,
    outputs = _extract_outputs,
    implementation = _extract_impl_legacy,
)

def _commit_impl(
        ctx,
        name = None,
        base = None,
        cmd = None,
        output_image_tar = None):
    """Implementation for the container_run_and_commit rule.

    This rule runs a set of commands in a given image, waits for the commands
    to finish, and then commits the container to a new image.

    Args:
        ctx: The bazel rule context
        name: A unique name for this rule.
        base: The input image
        cmd: str List, overrides ctx.attr.cmd
        output_image_tar: The output image obtained as a result of running
                          the commands on the input image
    """

    name = name or ctx.attr.name
    script = ctx.outputs.build
    output_image_tar = output_image_tar or ctx.outputs.out

    docker_run_flags = ""
    if ctx.attr.docker_run_flags != "":
        docker_run_flags = ctx.attr.docker_run_flags
    elif ctx.attr.base and ImageInfo in ctx.attr.base:
        docker_run_flags = ctx.attr.base[ImageInfo].docker_run_flags
    if "-d" not in docker_run_flags:
        docker_run_flags += " -d"

    run_image = "%s.run" % name
    run_image_output_executable = ctx.actions.declare_file("%s.executable" % run_image)
    run_image_output_tarball = ctx.actions.declare_file("%s.tar" % run_image)
    run_image_output_config = ctx.actions.declare_file("%s.json" % run_image)
    run_image_output_config_digest = ctx.actions.declare_file("%s.json.sha256" % run_image)
    run_image_output_digest = ctx.actions.declare_file("%s.digest" % run_image)
    run_image_output_layer = ctx.actions.declare_file("%s-layer.tar" % run_image)

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    # Generate a shell script to execute the reset cmd
    image_utils = ctx.actions.declare_file("image_util.sh")
    ctx.actions.expand_template(
        template = ctx.file._image_utils_tpl,
        output = image_utils,
        substitutions = {
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
        },
        is_executable = True,
    )

    image_result = _image.implementation(
        ctx,
        name,
        base = base,
        cmd = cmd,
        output_executable = run_image_output_executable,
        output_tarball = run_image_output_tarball,
        output_config = run_image_output_config,
        output_config_digest = run_image_output_config_digest,
        output_digest = run_image_output_digest,
        output_layer = run_image_output_layer,
        action_run = True,
        docker_run_flags = docker_run_flags,
    )

    parent_parts = _get_layers(ctx, name, base or ctx.attr.base)
    parent_config = parent_parts.get("config")

    # Construct a temporary name based on the build target.
    tag_name = "{}:{}".format(_join_path(ctx.attr.repository, ctx.label.package), name)
    footer = ctx.actions.declare_file(name + "_footer.sh")

    ctx.actions.expand_template(
        template = ctx.file._run_tpl,
        output = footer,
        substitutions = {
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
            "%{parent_config}": parent_config.path,
            "%{legacy_load_behavior}": "false",
            "%{output_image}": tag_name,
            "%{output_tar}": output_image_tar.path,
            "%{util_script}": image_utils.path,
        },
    )

    ctx.actions.run_shell(
        inputs = [run_image_output_executable, footer],
        outputs = [script],
        mnemonic = "Concat",
        command = """
            set -eu
            cat {first} {second} > {output}
        """.format(
            first = run_image_output_executable.path,
            second = footer.path,
            output = script.path,
        ),
    )

    ctx.actions.run(
        executable = script,
        tools = image_result[1].default_runfiles.files.to_list() + [image_utils],
        inputs = [parent_config] if parent_config else [],
        outputs = [output_image_tar],
        use_default_shell_env = True,
    )

    return [
        DefaultInfo(
            files = depset([output_image_tar, script]),
        ),
    ]

_commit_attrs = dicts.add(_image.attrs, {
    "legacy_run_behavior": attr.bool(
        default = False,
    ),
    "_image_utils_tpl": attr.label(
        default = "//docker/util:image_util.sh.tpl",
        allow_single_file = True,
    ),
    "_run_tpl": attr.label(
        default = Label("//docker/util:commit.sh.tpl"),
        allow_single_file = True,
    ),
})

# @unsorted-dict-items
_commit_outputs = {
    "out": "%{name}_commit.tar",
    "build": "%{name}.build",
}

container_run_and_commit_rule = rule(
    attrs = _commit_attrs,
    cfg = _container.image.cfg,
    doc = ("This rule runs a set of commands in a given image, waits" +
           "for the commands to finish, and then commits the" +
           "container to a new image."),
    executable = False,
    outputs = _commit_outputs,
    implementation = _commit_impl,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

# Export container_run_and_commit rule for other bazel rules to depend on.
commit = struct(
    attrs = _commit_attrs,
    outputs = _commit_outputs,
    implementation = _commit_impl,
)

def _commit_impl_legacy(
        ctx,
        name = None,
        image = None,
        commands = None,
        docker_run_flags = None,
        output_image_tar = None):
    """Legacy implementation for the container_run_and_commit rule.

    Args:
        ctx: The bazel rule context
        name: A unique name for this rule.
        image: The input image tarball
        commands: The commands to run in the input imnage container
        docker_run_flags: String list, overrides ctx.attr.docker_run_flags
        output_image_tar: The output image obtained as a result of running
                          the commands on the input image
    """

    name = name or ctx.attr.name
    image = image or ctx.file.image
    commands = commands or ctx.attr.commands
    docker_run_flags = docker_run_flags or ctx.attr.docker_run_flags
    script = ctx.actions.declare_file(name + ".build")
    output_image_tar = output_image_tar or ctx.outputs.out

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    # Generate a shell script to execute the reset cmd
    image_utils = ctx.actions.declare_file("image_util.sh")
    ctx.actions.expand_template(
        template = ctx.file._image_utils_tpl,
        output = image_utils,
        substitutions = {
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
        },
        is_executable = True,
    )

    # Generate a shell script to execute the run statement
    ctx.actions.expand_template(
        template = ctx.file._run_tpl,
        output = script,
        substitutions = {
            "%{commands}": _process_commands(commands),
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_run_flags}": " ".join(docker_run_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
            "%{image_id_extractor_path}": ctx.executable._extract_image_id.path,
            "%{image_tar}": image.path,
            "%{legacy_load_behavior}": "true",
            "%{output_image}": "bazel/%s:%s" % (
                ctx.label.package or "default",
                name,
            ),
            "%{output_tar}": output_image_tar.path,
            "%{to_json_tool}": ctx.executable._to_json_tool.path,
            "%{util_script}": image_utils.path,
        },
        is_executable = True,
    )

    runfiles = [image, image_utils]

    ctx.actions.run(
        outputs = [output_image_tar],
        inputs = runfiles,
        executable = script,
        tools = [ctx.executable._extract_image_id, ctx.executable._to_json_tool],
        use_default_shell_env = True,
    )

    return []

_commit_attrs_legacy = {
    "commands": attr.string_list(
        doc = "A list of commands to run (sequentially) in the container.",
        mandatory = True,
        allow_empty = False,
    ),
    "docker_run_flags": attr.string_list(
        doc = "Extra flags to pass to the docker run command.",
        mandatory = False,
    ),
    "image": attr.label(
        doc = "The image to run the commands in.",
        mandatory = True,
        allow_single_file = True,
        cfg = "target",
    ),
    "_extract_image_id": attr.label(
        default = Label("//contrib:extract_image_id"),
        cfg = "exec",
        executable = True,
        allow_files = True,
    ),
    "_image_utils_tpl": attr.label(
        default = "//docker/util:image_util.sh.tpl",
        allow_single_file = True,
    ),
    "_run_tpl": attr.label(
        default = Label("//docker/util:commit.sh.tpl"),
        allow_single_file = True,
    ),
    "_to_json_tool": attr.label(
        default = Label("//docker/util:to_json"),
        cfg = "exec",
        executable = True,
        allow_files = True,
    ),
}

container_run_and_commit_legacy = rule(
    attrs = _commit_attrs_legacy,
    doc = ("This rule runs a set of commands in a given image, waits" +
           "for the commands to finish, and then commits the" +
           "container to a new image."),
    executable = False,
    outputs = _commit_outputs,
    implementation = _commit_impl_legacy,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def container_run_and_commit(name, legacy_load_behavior = True, **kwargs):
    if legacy_load_behavior:
        container_run_and_commit_legacy(
            name = name,
            **kwargs
        )
    else:
        container_run_and_commit_rule(
            name = name,
            **kwargs
        )

def _commit_layer_impl(
        ctx,
        name = None,
        base = None,
        cmd = None,
        env = None,
        compression = None,
        compression_options = None,
        output_layer_tar = None):
    """Implementation for the container_run_and_commit_layer rule.

    This rule runs a set of commands in a given image, waits for the commands
    to finish, and then extracts the layer of changes into a new container_layer target.

    Args:
        ctx: The bazel rule context
        name: A unique name for this rule.
        base: File, overrides ctx.attr.base
        cmd: str List, overrides ctx.attr.cmd
        env: str Dict, overrides ctx.attr.env
        compression: str, overrides ctx.attr.compression
        compression_options: str list, overrides ctx.attr.compression_options
        output_layer_tar: The output layer obtained as a result of running
                          the commands on the input image
    """

    name = name or ctx.attr.name
    script = ctx.actions.declare_file(name + ".build")
    output_layer_tar = output_layer_tar or ctx.outputs.layer
    env = env or ctx.attr.env
    compression = compression or ctx.attr.compression
    compression_options = compression_options or ctx.attr.compression_options

    docker_run_flags = ""
    if ctx.attr.docker_run_flags != "":
        docker_run_flags = ctx.attr.docker_run_flags
    elif ctx.attr.base and ImageInfo in ctx.attr.base:
        docker_run_flags = ctx.attr.base[ImageInfo].docker_run_flags
    if "-d" not in docker_run_flags:
        docker_run_flags += " -d"

    run_image = "%s.run" % name
    run_image_output_executable = ctx.actions.declare_file("%s.executable" % run_image)
    run_image_output_tarball = ctx.actions.declare_file("%s.tar" % run_image)
    run_image_output_config = ctx.actions.declare_file("%s.json" % run_image)
    run_image_output_config_digest = ctx.actions.declare_file("%s.json.sha256" % run_image)
    run_image_output_digest = ctx.actions.declare_file("%s.digest" % run_image)
    run_image_output_layer = ctx.actions.declare_file("%s-layer.tar" % run_image)

    image_result = _image.implementation(
        ctx,
        name,
        base = base,
        cmd = cmd,
        output_executable = run_image_output_executable,
        output_tarball = run_image_output_tarball,
        output_config = run_image_output_config,
        output_config_digest = run_image_output_config_digest,
        output_digest = run_image_output_digest,
        output_layer = run_image_output_layer,
        action_run = True,
        docker_run_flags = docker_run_flags,
    )

    parent_parts = _get_layers(ctx, name, base or ctx.attr.base)
    parent_config = parent_parts.get("config")

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    # Generate a shell script to execute the reset cmd
    image_utils = ctx.actions.declare_file("image_util.sh")
    ctx.actions.expand_template(
        template = ctx.file._image_utils_tpl,
        output = image_utils,
        substitutions = {
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
        },
        is_executable = True,
    )

    docker_env = [
        "{}={}".format(
            ctx.expand_make_variables("env", key, {}),
            ctx.expand_make_variables("env", value, {}),
        )
        for key, value in env.items()
    ]

    env_file = ctx.actions.declare_file(name + ".env")
    ctx.actions.write(env_file, "\n".join(docker_env))

    output_diff_id = ctx.actions.declare_file(output_layer_tar.basename + ".sha256")
    footer = ctx.actions.declare_file(name + "_footer.sh")

    # Generate a shell script to execute the run statement and extract the layer
    ctx.actions.expand_template(
        template = ctx.file._run_tpl,
        output = footer,
        substitutions = {
            "%{env_file_path}": env_file.path,
            "%{parent_config}": parent_config.path,
            "%{legacy_load_behavior}": "false",
            "%{output_diff_id}": output_diff_id.path,
            "%{image_id_extractor_path}": ctx.executable._extract_image_id.path,
            "%{image_last_layer_extractor_path}": ctx.executable._last_layer_extractor_tool.path,
            "%{output_image}": "bazel/%s:%s" % (
                ctx.label.package or "default",
                name,
            ),
            "%{output_layer_tar}": output_layer_tar.path,
            "%{util_script}": image_utils.path,
        },
        is_executable = True,
    )

    ctx.actions.run_shell(
        inputs = [run_image_output_executable, footer],
        outputs = [script],
        mnemonic = "Concat",
        command = """
            set -eu
            cat {first} {second} > {output}
        """.format(
            first = run_image_output_executable.path,
            second = footer.path,
            output = script.path,
        ),
    )

    ctx.actions.run(
        outputs = [output_layer_tar, output_diff_id],
        inputs = [image_utils],
        executable = script,
        execution_requirements = {
            # This action produces large output files, and isn't economical to
            # upload to a remote cache.
            "no-remote-cache": "1",
        },
        mnemonic = "RunAndCommitLayer",
        tools = [ctx.executable._extract_image_id, ctx.executable._last_layer_extractor_tool] + image_result[1].default_runfiles.files.to_list(),
        use_default_shell_env = True,
    )

    # Generate a zipped layer and calculate the blob sum, this is for LayerInfo
    zipped_layer, blob_sum = zip_layer(
        ctx,
        output_layer_tar,
        compression = compression,
        compression_options = compression_options,
    )

    return [
        LayerInfo(
            unzipped_layer = output_layer_tar,
            diff_id = output_diff_id,
            zipped_layer = zipped_layer,
            blob_sum = blob_sum,
            env = env,
        ),
    ]

_commit_layer_attrs = dicts.add(_image.attrs, {
    "legacy_run_behavior": attr.bool(
        default = False,
    ),
    "compression": attr.string(default = "gzip"),
    "compression_options": attr.string_list(),
    "_run_tpl": attr.label(
        default = Label("//docker/util:commit_layer.sh.tpl"),
        allow_single_file = True,
    ),
    "_extract_image_id": attr.label(
        default = Label("//contrib:extract_image_id"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "_image_utils_tpl": attr.label(
        default = "//docker/util:image_util.sh.tpl",
        allow_single_file = True,
    ),
    "_last_layer_extractor_tool": attr.label(
        default = Label("//contrib:extract_last_layer"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
})

_commit_layer_outputs = {
    "layer": "%{name}-layer.tar",
    "script": "%{name}.build",
}

container_run_and_commit_layer_rule = rule(
    attrs = _commit_layer_attrs,
    cfg = _container.image.cfg,
    doc = ("This rule runs a set of commands in a given image, waits" +
           "for the commands to finish, and then commits the" +
           "container state to a new layer."),
    executable = False,
    outputs = _commit_layer_outputs,
    implementation = _commit_layer_impl,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def _commit_layer_impl_legacy(
        ctx,
        name = None,
        image = None,
        commands = None,
        docker_run_flags = None,
        env = None,
        compression = None,
        compression_options = None,
        output_layer_tar = None):
    """Implementation for the container_run_and_commit_layer rule.

    This rule runs a set of commands in a given image, waits for the commands
    to finish, and then extracts the layer of changes into a new container_layer target.

    Args:
        ctx: The bazel rule context
        name: A unique name for this rule.
        image: The input image tarball
        commands: The commands to run in the input image container
        docker_run_flags: String list, overrides ctx.attr.docker_run_flags
        env: str Dict, overrides ctx.attr.env
        compression: str, overrides ctx.attr.compression
        compression_options: str list, overrides ctx.attr.compression_options
        output_layer_tar: The output layer obtained as a result of running
                          the commands on the input image
    """

    name = name or ctx.attr.name
    image = image or ctx.file.image
    commands = commands or ctx.attr.commands
    docker_run_flags = docker_run_flags or ctx.attr.docker_run_flags
    env = env or ctx.attr.env
    script = ctx.actions.declare_file(name + ".build")
    compression = compression or ctx.attr.compression
    compression_options = compression_options or ctx.attr.compression_options
    output_layer_tar = output_layer_tar or ctx.outputs.layer

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    # Generate a shell script to execute the reset cmd
    image_utils = ctx.actions.declare_file("image_util.sh")
    ctx.actions.expand_template(
        template = ctx.file._image_utils_tpl,
        output = image_utils,
        substitutions = {
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
        },
        is_executable = True,
    )

    docker_env = [
        "{}={}".format(
            ctx.expand_make_variables("env", key, {}),
            ctx.expand_make_variables("env", value, {}),
        )
        for key, value in env.items()
    ]

    env_file = ctx.actions.declare_file(name + ".env")
    ctx.actions.write(env_file, "\n".join(docker_env))

    output_diff_id = ctx.actions.declare_file(output_layer_tar.basename + ".sha256")

    # Generate a shell script to execute the run statement and extract the layer
    ctx.actions.expand_template(
        template = ctx.file._run_tpl,
        output = script,
        substitutions = {
            "%{commands}": _process_commands(commands),
            "%{legacy_load_behavior}": "true",
            "%{parent_config}": "",
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_run_flags}": " ".join(docker_run_flags),
            "%{docker_tool_path}": docker_path(toolchain_info),
            "%{env_file_path}": env_file.path,
            "%{image_id_extractor_path}": ctx.executable._extract_image_id.path,
            "%{image_last_layer_extractor_path}": ctx.executable._last_layer_extractor_tool.path,
            "%{image_tar}": image.path,
            "%{output_diff_id}": output_diff_id.path,
            "%{output_image}": "bazel/%s:%s" % (
                ctx.label.package or "default",
                name,
            ),
            "%{output_layer_tar}": output_layer_tar.path,
            "%{util_script}": image_utils.path,
        },
        is_executable = True,
    )

    runfiles = [image, image_utils, env_file]

    ctx.actions.run(
        outputs = [output_layer_tar, output_diff_id],
        inputs = runfiles,
        executable = script,
        mnemonic = "RunAndCommitLayer",
        tools = [ctx.executable._extract_image_id, ctx.executable._last_layer_extractor_tool],
        use_default_shell_env = True,
    )

    # Generate a zipped layer and calculate the blob sum, this is for LayerInfo
    zipped_layer, blob_sum = zip_layer(
        ctx,
        output_layer_tar,
        compression = compression,
        compression_options = compression_options,
    )

    return [
        LayerInfo(
            unzipped_layer = output_layer_tar,
            diff_id = output_diff_id,
            zipped_layer = zipped_layer,
            blob_sum = blob_sum,
            env = env,
        ),
    ]

_commit_layer_attrs_legacy = dicts.add({
    "commands": attr.string_list(
        doc = "A list of commands to run (sequentially) in the container.",
        mandatory = True,
        allow_empty = False,
    ),
    "compression": attr.string(default = "gzip"),
    "compression_options": attr.string_list(),
    "docker_run_flags": attr.string_list(
        doc = "Extra flags to pass to the docker run command.",
        mandatory = False,
    ),
    "env": attr.string_dict(),
    "image": attr.label(
        doc = "The image to run the commands in.",
        mandatory = True,
        allow_single_file = True,
        cfg = "target",
    ),
    "_extract_image_id": attr.label(
        default = Label("//contrib:extract_image_id"),
        cfg = "exec",
        executable = True,
        allow_files = True,
    ),
    "_image_utils_tpl": attr.label(
        default = "//docker/util:image_util.sh.tpl",
        allow_single_file = True,
    ),
    "_last_layer_extractor_tool": attr.label(
        default = Label("//contrib:extract_last_layer"),
        cfg = "exec",
        executable = True,
        allow_files = True,
    ),
    "_run_tpl": attr.label(
        default = Label("//docker/util:commit_layer.sh.tpl"),
        allow_single_file = True,
    ),
}, _hash_tools, _zip_tools)

container_run_and_commit_layer_legacy = rule(
    attrs = _commit_layer_attrs_legacy,
    doc = ("This rule runs a set of commands in a given image, waits" +
           "for the commands to finish, and then commits the" +
           "container state to a new layer."),
    executable = False,
    outputs = _commit_layer_outputs,
    implementation = _commit_layer_impl_legacy,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def container_run_and_commit_layer(name, legacy_load_behavior = True, **kwargs):
    if legacy_load_behavior:
        container_run_and_commit_layer_legacy(
            name = name,
            **kwargs
        )
    else:
        container_run_and_commit_layer_rule(
            name = name,
            legacy_load_behavior = False,
            **kwargs
        )

# Export container_run_and_commit_layer rule for other bazel rules to depend on.
commit_layer = struct(
    attrs = _commit_layer_attrs_legacy,
    outputs = _commit_layer_outputs,
    implementation = _commit_layer_impl_legacy,
)

def _process_commands(command_list):
    # Use the $ to allow escape characters in string
    return 'sh -c $\"{0}\"'.format(" && ".join(command_list))
