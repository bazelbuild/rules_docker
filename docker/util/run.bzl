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

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    # Generate a shell script to execute the run statement
    ctx.actions.expand_template(
        template = ctx.file._extract_tpl,
        output = script,
        substitutions = {
            "%{commands}": _process_commands(commands),
            "%{docker_run_flags}": " ".join(docker_run_flags),
            "%{docker_tool_path}": toolchain_info.tool_path,
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

    return struct()

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

    # Generate a shell script to execute the run statement
    ctx.actions.expand_template(
        template = ctx.file._run_tpl,
        output = script,
        substitutions = {
            "%{commands}": _process_commands(commands),
            "%{docker_run_flags}": " ".join(docker_run_flags),
            "%{docker_tool_path}": toolchain_info.tool_path,
            "%{image_id_extractor_path}": ctx.executable._extract_image_id.path,
            "%{image_tar}": image.path,
            "%{output_image}": "bazel/%s:%s" % (
                ctx.label.package or "default",
                name,
            ),
            "%{output_tar}": output_image_tar.path,
            "%{to_json_tool}": ctx.executable._to_json_tool.path,
            "%{util_script}": ctx.file._image_utils.path,
        },
        is_executable = True,
    )

    runfiles = [image, ctx.file._image_utils]

    ctx.actions.run(
        outputs = [output_image_tar],
        inputs = runfiles,
        executable = script,
        tools = [ctx.executable._extract_image_id, ctx.executable._to_json_tool],
        use_default_shell_env = True,
    )

    return struct()

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
    "_image_utils": attr.label(
        default = "//docker/util:image_util.sh",
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
_commit_outputs = {
    "out": "%{name}_commit.tar",
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

def _process_commands(command_list):
    # Use the $ to allow escape characters in string
    return 'sh -c $\"{0}\"'.format(" && ".join(command_list))
