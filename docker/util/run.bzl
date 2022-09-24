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
load("@io_bazel_rules_docker//container:layer.bzl", "zip_layer")
load("@io_bazel_rules_docker//container:providers.bzl", "LayerInfo")
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
        image = None,
        commands = None,
        docker_run_flags = None,
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

_extract_attrs = {
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
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "_extract_tpl": attr.label(
        default = Label("//docker/util:extract.sh.tpl"),
        allow_single_file = True,
    ),
}

_extract_outputs = {
    "out": "%{name}%{extract_file}",
    "script": "%{name}.build",
}

# Export container_run_and_extract rule for other bazel rules to depend on.
extract = struct(
    attrs = _extract_attrs,
    outputs = _extract_outputs,
    implementation = _extract_impl,
)

container_run_and_extract = rule(
    attrs = _extract_attrs,
    doc = ("This rule runs a set of commands in a given image, waits" +
           "for the commands to finish, and then extracts a given file" +
           " from the container to the bazel-out directory."),
    outputs = _extract_outputs,
    implementation = _extract_impl,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

def _commit_impl(
        ctx,
        name = None,
        image = None,
        commands = None,
        docker_run_flags = None,
        output_image_tar = None):
    """Implementation for the container_run_and_commit rule.

    This rule runs a set of commands in a given image, waits for the commands
    to finish, and then commits the container to a new image.

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

_commit_attrs = {
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
        cfg = "host",
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
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}

# @unsorted-dict-items
_commit_outputs = {
    "out": "%{name}_commit.tar",
    "build": "%{name}.build",
}

container_run_and_commit = rule(
    attrs = _commit_attrs,
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

def _commit_layer_impl(
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

_commit_layer_attrs = dicts.add({
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
    "_run_tpl": attr.label(
        default = Label("//docker/util:commit_layer.sh.tpl"),
        allow_single_file = True,
    ),
}, _hash_tools, _zip_tools)

_commit_layer_outputs = {
    "layer": "%{name}-layer.tar",
}

container_run_and_commit_layer = rule(
    attrs = _commit_layer_attrs,
    doc = ("This rule runs a set of commands in a given image, waits" +
           "for the commands to finish, and then commits the" +
           "container state to a new layer."),
    executable = False,
    outputs = _commit_layer_outputs,
    implementation = _commit_layer_impl,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)

# Export container_run_and_commit_layer rule for other bazel rules to depend on.
commit_layer = struct(
    attrs = _commit_layer_attrs,
    outputs = _commit_layer_outputs,
    implementation = _commit_layer_impl,
)

def _process_commands(command_list):
    # Use the $ to allow escape characters in string
    return 'sh -c $\"{0}\"'.format(" && ".join(command_list))
