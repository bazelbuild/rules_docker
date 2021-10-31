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
Defines a rule to validate YAML configs used to configure automatic container
release.
"""

load(
    "//skylib:path.bzl",
    "runfile",
)
load(
    "//skylib:docker.bzl",
    "docker_path",
)

def _get_runfile_path(ctx, f):
    return "${RUNFILES}/%s" % runfile(ctx, f)

def _impl(ctx):
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    cmd_args = ["-logtostderr=true"]

    # specs is the list of abosoluate runfile paths to all the spec files that
    # need to be copied on to the checker container.
    specs = []

    # spec_container_paths is the corresponding path in the container the spec
    # files from 'specs' will be copied to.
    spec_container_paths = []

    # file_update_specs is the paths in the container to the file update spec
    # files.
    file_update_specs = []

    # dependency_update_specs is the paths in the container to the dependency
    # update spec files.
    dependency_update_specs = []
    for f in ctx.files.file_update_specs:
        specs.append(_get_runfile_path(ctx, f))
        container_path = "/" + f.short_path.replace("/", "-")
        spec_container_paths.append(container_path)
        file_update_specs.append(container_path)

    if len(file_update_specs) > 0:
        cmd_args += [
            "-fileUpdateSpecs",
            ",".join(file_update_specs),
        ]
    for f in ctx.files.dependency_update_specs:
        specs.append(_get_runfile_path(ctx, f))
        container_path = "/" + f.short_path.replace("/", "-")
        spec_container_paths.append(container_path)
        dependency_update_specs.append(container_path)
    if len(dependency_update_specs) > 0:
        cmd_args += [
            "-depSpecs",
            ",".join(dependency_update_specs),
        ]

    ctx.actions.expand_template(
        template = ctx.file._tpl,
        substitutions = {
            "%{cmd_args}": " ".join(cmd_args),
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_path}": docker_path(toolchain_info),
            "%{image_name}": ctx.attr._checker + ":" + ctx.attr.checker_tag,
            "%{spec_container_paths}": " ".join(spec_container_paths),
            "%{specs}": " ".join(specs),
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = ctx.files.file_update_specs + ctx.files.dependency_update_specs)
    return [DefaultInfo(runfiles = runfiles)]

configs_test = rule(
    attrs = {
        "checker_tag": attr.string(
            default = "latest",
            values = ["latest", "staging", "test"],
            doc = "Tag of the semantics checker image to be used for validation.",
        ),
        "dependency_update_specs": attr.label_list(
            allow_files = ["yaml"],
            doc = "Dependency update YAML dep spec files to validate.",
        ),
        "file_update_specs": attr.label_list(
            allow_files = ["yaml"],
            doc = "File update YAML spec files to validate.",
        ),
        "_checker": attr.string(
            default = "gcr.io/asci-toolchain/container_release_tools/dependency_update/validators/semantics",
            doc = "Name of the checker image to run.",
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
