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
Defines a rule to syntax check a single dependency update YAML spec.
"""

load("//contrib/automatic_container_release:checker_image.bzl", "checker_image")
load(
    "//skylib:path.bzl",
    "runfile",
)

def _get_runfile_path(ctx, f):
    return "${RUNFILES}/%s" % runfile(ctx, f)

def _impl(ctx):
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    cmd_args = [
        "-logtostderr=true",
        "-format=dep_spec",
        "-specFile={}".format(ctx.file.spec.short_path),
    ]
    ctx.actions.expand_template(
        template = ctx.file._tpl,
        substitutions = {
            "%{cmd_args}": " ".join(cmd_args),
            "%{docker_path}": toolchain_info.tool_path,
            "%{docker_run_args}": "",
            "%{image_id_loader}": _get_runfile_path(ctx, ctx.executable._extract_image_id),
            "%{image_tar}": _get_runfile_path(ctx, ctx.file.image_tar),
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )
    runfiles = ctx.runfiles(
        files = [
            ctx.file.spec,
            ctx.file.image_tar,
        ] + ctx.files._extract_image_id,
    )
    return [DefaultInfo(runfiles = runfiles)]

_dependency_update_test = rule(
    attrs = {
        "image_tar": attr.label(
            allow_single_file = ["tar"],
            doc = "Path to the docker image for the syntax checker with the" +
                  " spec file included in the image.",
        ),
        "spec": attr.label(
            allow_single_file = ["yaml"],
            doc = "File update YAML spec file to validate.",
        ),
        "_extract_image_id": attr.label(
            default = "@io_bazel_rules_docker//contrib:extract_image_id",
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
        "_tpl": attr.label(
            default = "@io_bazel_rules_docker//contrib/automatic_container_release:run_checker.sh.tpl",
            allow_single_file = True,
        ),
    },
    test = True,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _impl,
)

def dependency_update_test(name, spec):
    # First build an image that includes both the checker binary as well as
    # the spec file.
    img_target = "{}-image".format(name)
    checker_image(
        name = img_target,
        base = "@dependency_update_syntax_checker//image",
        spec = spec,
    )
    _dependency_update_test(
        name = name,
        spec = spec,
        image_tar = img_target + ".tar",
    )
