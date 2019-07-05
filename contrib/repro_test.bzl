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

"""Test rule for verifying a given container_image target produces a
   deterministic Docker image.

This rule builds the given container_image twice in isolation to determine if
the given image is deterministic.
It does so by mounting the provided Bazel project files into the 'base' image.
Next it starts two containers and builds the supplied container_image target
(being 'image') inside each of the containers. The rule then extracts the
output files for the test image. Finally, both extracted images are compared.
A test image is considered to be reproducible when both instances of the same
image have the same digest and ID. On a mismatch of one of those values, the
test fails and the container_diff tool
(https://github.com/GoogleContainerTools/container-diff#container-diff)
produces the summary of their differences.

Args:
    image: A container_image target relative to the project's root to test
           for determinism.
    src_project_files: A target that exposes the files of the Bazel project to
                       build the 'image' in (e.g. filegroup target).
    base: An image target to build and reproduce the 'image 'in.
          This image must have Bazel and docker installed and available in the PATH.
    container_diff_args: (optional) Args to the container_diff tool as specified here:
                         https://github.com/GoogleContainerTools/container-diff#quickstart

Example:

container_repro_test(
    name = "set_cmd_repro_test",
    image = "//tests/container:set_cmd",
    base = "@bazel_latest//image",
    src_project_files = "//:src_project",
    container_diff_args: ["history", "file", "size", "rpm", "apt", "pip", "node"],
)
"""

load("@base_images_docker//util:run.bzl", _extract = "extract")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//container:container.bzl", _container = "container")
load("//skylib:filetype.bzl", container_filetype = "container")

def _impl(ctx):
    """Core implementation of container_repro_test"""

    # Check for existence of the WORKSPACE file in the files provided.
    src_project_files = ctx.files.src_project_files
    workspace_file = None
    for f in src_project_files:
        if f.basename == "WORKSPACE":
            workspace_file = f
            break

    if not workspace_file:
        fail("A WORKSPACE file must be among the src_project_files provided files.")

    name = ctx.attr.name

    # Record the absolute path to the provided WORKSPACE file and assume it to
    # be the root of the Bazel project to build the 'image' in.
    proj_root = ctx.actions.declare_file(name + "_src_project_root.txt")
    ctx.actions.run_shell(
        command = "readlink -f %s | xargs dirname >> %s" % (workspace_file.path, proj_root.path),
        inputs = [workspace_file],
        outputs = [proj_root],
    )

    src_paths = [f.path for f in src_project_files]
    proj_tar = ctx.actions.declare_file(name + "_src_project.tar")

    # Tar the provided source project files to mount into the image that will
    # be used to build and repro the 'image' in.
    ctx.actions.run_shell(
        command = "readlink -f %s | xargs tar -cvf %s" % (" ".join(src_paths), proj_tar.path),
        inputs = src_project_files,
        outputs = [proj_tar],
    )

    image_tar = ctx.actions.declare_file(name + ".tar")

    # Build the Bazel image to build and repro the 'image' in.
    # Mount the source project and its path into this image.
    _container.image.implementation(
        ctx,
        files = [proj_root],
        tars = [proj_tar],
        output_executable = ctx.actions.declare_file(name + "_load.sh"),
        output_tarball = image_tar,
        workdir = "/",
    )

    img_label = ctx.attr.image.label
    img_target_str = "//" + img_label.package + ":" + img_label.name

    build_targets = [
        img_target_str,
        img_target_str + ".tar",
        img_target_str + ".digest",
        img_target_str + ".json",
    ]
    extract_path = "/img_outs"
    commands = [
        "cd \$(cat /%s)" % proj_root.basename,
        "bazel build " + " ".join(build_targets),
        "cp -r bazel-bin/%s %s" % (img_label.package, extract_path),
    ]
    docker_run_flags = ["--entrypoint", "''"]

    img1_outs = ctx.outputs.img1_outs
    img2_outs = ctx.outputs.img2_outs

    # Build and extract 'image' inside a container.
    _extract.implementation(
        ctx,
        name = "build_image_and_extract",
        commands = commands,
        extract_file = extract_path,
        image = image_tar,
        docker_run_flags = docker_run_flags,
        output_file = img1_outs,
        script_file = ctx.actions.declare_file(name + ".build"),
    )

    # Build and extract 'image' again in a different container to try and
    # repro previously built 'image'.
    _extract.implementation(
        ctx,
        name = "build_image_and_extract_repro",
        commands = commands,
        extract_file = extract_path,
        image = image_tar,
        docker_run_flags = docker_run_flags,
        output_file = img2_outs,
        script_file = ctx.actions.declare_file(name + "_repro.build"),
    )

    # Expand template to run the image comparison test.
    type_args = ["--type=" + type_arg for type_arg in ctx.attr.container_diff_args]
    diff_tool_exec = ctx.executable._container_diff_tool
    ctx.actions.expand_template(
        template = ctx.file._test_tpl,
        substitutions = {
            "%{container_diff_args}": " ".join(type_args),
            "%{container_diff_tool}": diff_tool_exec.short_path,
            "%{img1_path}": img1_outs.short_path,
            "%{img2_path}": img2_outs.short_path,
            "%{img_name}": img_label.name,
        },
        output = ctx.outputs.test_script,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [img1_outs, img2_outs, diff_tool_exec])

    return [
        DefaultInfo(
            executable = ctx.outputs.test_script,
            runfiles = runfiles,
        ),
    ]

container_repro_test = rule(
    attrs = dicts.add(_container.image.attrs, {
        "base": attr.label(
            allow_files = container_filetype,
            mandatory = True,
            doc = "An image target compatible with the `base` attribute of " +
                  "the container_image rule to build and reproduce the " +
                  "'image' in. This image must have Bazel and docker " +
                  "installed and available in the PATH.",
        ),
        "container_diff_args": attr.string_list(
            default = ["file", "size", "apt", "pip"],
            doc = "List of the --type flag values to pass to the container_diff tool. " +
                  "Check https://github.com/GoogleContainerTools/container-diff#container-diff " +
                  "for more info.",
        ),
        "image": attr.label(
            mandatory = True,
            doc = "A container_image target to test for reproducibility.",
        ),
        # TODO(alex1545): Remove this attribute once able to get the project's
        # root differently (possibly via a new repo rule).
        "src_project_files": attr.label(
            allow_files = True,
            mandatory = True,
            doc = "Files of the source project where the 'image' target " +
                  "lives. The WORKSPACE file must be specified and is " +
                  "assumed to be at the root of the project.",
        ),
        "_container_diff_tool": attr.label(
            default = Label("@container_diff//file"),
            allow_single_file = True,
            cfg = "target",
            executable = True,
        ),
        "_extract_tpl": attr.label(
            default = Label("@base_images_docker//util:extract.sh.tpl"),
            allow_single_file = True,
        ),
        "_image_id_extractor": attr.label(
            default = "//contrib:extract_image_id.py",
            allow_single_file = True,
        ),
        "_test_tpl": attr.label(
            default = Label("//contrib:cmp_images.sh.tpl"),
            allow_single_file = True,
            doc = "A template to expand a bash script to run a complete " +
                  "image comparison test.",
        ),
    }),
    implementation = _impl,
    outputs = dicts.add(_container.image.outputs, {
        "img1_outs": "%{name}_test_img1_outs",
        "img2_outs": "%{name}_test_img2_outs",
        "test_script": "%{name}.test",
    }),
    test = True,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)
