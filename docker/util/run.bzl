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

def _extract_impl(ctx, name = "", image = None, commands = None, docker_run_flags = None, extract_file = "", output_file = "", script_file = ""):
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
    """
    name = name or ctx.label.name
    image = image or ctx.file.image
    commands = commands or ctx.attr.commands
    docker_run_flags = docker_run_flags or ctx.attr.docker_run_flags
    extract_file = extract_file or ctx.attr.extract_file
    output_file = output_file or ctx.outputs.out
    script = script_file or ctx.outputs.script

    # Generate a shell script to execute the run statement
    ctx.actions.expand_template(
        template = ctx.file._extract_tpl,
        output = script,
        substitutions = {
            "%{commands}": _process_commands(commands),
            "%{docker_run_flags}": " ".join(docker_run_flags),
            "%{extract_file}": extract_file,
            "%{image_id_extractor_path}": ctx.file._image_id_extractor.path,
            "%{image_tar}": image.path,
            "%{output}": output_file.path,
        },
        is_executable = True,
    )

    ctx.actions.run(
        outputs = [output_file],
        tools = [image, ctx.file._image_id_extractor],
        executable = script,
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
    "_extract_tpl": attr.label(
        default = Label("//docker/util:extract.sh.tpl"),
        allow_single_file = True,
    ),
    "_image_id_extractor": attr.label(
        default = "//contrib:extract_image_id.py",
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
)

def _commit_impl(
        ctx,
        name = None,
        image = None,
        commands = None,
        output_image_tar = None):
    """Implementation for the container_run_and_commit rule.

    This rule runs a set of commands in a given image, waits for the commands
    to finish, and then commits the container to a new image.

    Args:
        ctx: The bazel rule context
        name: A unique name for this rule.
        image: The input image tarball
        commands: The commands to run in the input imnage container
        output_image_tar: The output image obtained as a result of running
                          the commands on the input image
    """

    name = name or ctx.attr.name
    image = image or ctx.file.image
    commands = commands or ctx.attr.commands
    script = ctx.actions.declare_file(name + ".build")
    output_image_tar = output_image_tar or ctx.outputs.out

    # Generate a shell script to execute the run statement
    ctx.actions.expand_template(
        template = ctx.file._run_tpl,
        output = script,
        substitutions = {
            "%{commands}": _process_commands(commands),
            "%{image_id_extractor_path}": ctx.file._image_id_extractor.path,
            "%{image_tar}": image.path,
            "%{output_image}": "bazel/%s:%s" % (
                ctx.label.package or "default",
                name,
            ),
            "%{output_tar}": output_image_tar.path,
            "%{util_script}": ctx.file._image_utils.path,
        },
        is_executable = True,
    )

    runfiles = [image, ctx.file._image_utils, ctx.file._image_id_extractor]

    ctx.actions.run(
        outputs = [output_image_tar],
        inputs = runfiles,
        executable = script,
    )

    return struct()

_commit_attrs = {
    "commands": attr.string_list(
        doc = "A list of commands to run (sequentially) in the container.",
        mandatory = True,
        allow_empty = False,
    ),
    "image": attr.label(
        doc = "The image to run the commands in.",
        mandatory = True,
        allow_single_file = True,
        cfg = "target",
    ),
    "_image_id_extractor": attr.label(
        default = "//contrib:extract_image_id.py",
        allow_single_file = True,
    ),
    "_image_utils": attr.label(
        default = "//docker/util:image_util.sh",
        allow_single_file = True,
    ),
    "_run_tpl": attr.label(
        default = Label("//docker/util:commit.sh.tpl"),
        allow_single_file = True,
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
