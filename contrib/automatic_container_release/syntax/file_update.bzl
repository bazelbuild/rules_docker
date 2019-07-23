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
Defines a rule to syntax check a single file update YAML spec.
"""

load(
    "//skylib:path.bzl",
    "runfile",
)

def _get_runfile_path(ctx, f):
    return "${RUNFILES}/%s" % runfile(ctx, f)

def _impl(ctx):
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    spec_file_container_path = "/" + ctx.file.spec.short_path.replace("/", "-")
    cmd_args = [
        "-logtostderr=true",
        "-specFile={}".format(spec_file_container_path),
    ]
    ctx.actions.expand_template(
        template = ctx.file._tpl,
        substitutions = {
            "%{cmd_args}": " ".join(cmd_args),
            "%{docker_path}": toolchain_info.tool_path,
            "%{image_name}": ctx.attr._checker,
            "%{spec_file_path}": _get_runfile_path(ctx, ctx.file.spec),
            "%{spec_file_container_path}": spec_file_container_path,
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [ctx.file.spec])
    return [DefaultInfo(runfiles = runfiles)]

file_update_test = rule(
    attrs = {
        "spec": attr.label(
            allow_single_file = ["yaml"],
            doc = "File update YAML spec file to validate.",
        ),
        "_tpl": attr.label(
            default = "@io_bazel_rules_docker//contrib/automatic_container_release:run_checker.sh.tpl",
            allow_single_file = True,
        ),
        "_checker": attr.string(
            default = "gcr.io/asci-toolchain/container_release_tools/file_update/validators/syntax",
            doc = "Name of the checker image to run."
        ),
    },
    test = True,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _impl,
)
