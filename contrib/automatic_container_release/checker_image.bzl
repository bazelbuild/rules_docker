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
Builds a container image with a given automatic_container_image YAML spec &
the checker binary so that the container can be run to check the YAML without
having to separately mount or copy in the YAML spec.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//container:image.bzl", "image")

def _impl(ctx):
    spec = ctx.file.spec
    return image.implementation(
        ctx,
        base = ctx.files.base[0],
        file_map = {
            "/workspace/{}".format(spec.short_path): spec,
        },
        # This will allow the checker to accept the "short_path" to read the
        # spec from. This should correlate nicely with the location of the
        # spec file in the Bazel workspace. This will make log messages from the
        # checker referring to the location of the spec file more user
        # friendly.
        workdir = "/workspace",
    )

_attrs = dicts.add(
    image.attrs,
    {
        "spec": attr.label(
            allow_single_file = ["yaml"],
            doc = "YAML spec file to validate that will be added to the image.",
        ),
    },
)
checker_image = rule(
    attrs = _attrs,
    outputs = image.outputs,
    implementation = _impl,
    executable = True,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
)
