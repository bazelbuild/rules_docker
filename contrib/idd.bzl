# Copyright 2015 The Bazel Authors. All rights reserved.
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
load(
    "//skylib:filetype.bzl",
    container_filetype = "container",
)

# Implementation of idd
def _impl(ctx):
    runfiles = ctx.runfiles(files = [ctx.file.image1, ctx.file.image2] + ctx.files._idd_script)

    ctx.actions.write(
        output = ctx.outputs.executable,
        content = "set -x && python {idd_script} {tar1_path} {tar2_path} {args}".format(
            idd_script = ctx.executable._idd_script.short_path,
            tar1_path = ctx.file.image1.short_path,
            tar2_path = ctx.file.image2.short_path,
            args = " ".join(ctx.attr.args),
        ),
    )

    return [DefaultInfo(runfiles = runfiles)]

"""
Bazel wrapper for the idd.py script.
Used for finding differences between image targets.

Args:
    image1: Image target or image tarball file (from docker save) - first image to compare
    image2: Image target or image tarball file (from docker save) - second image to compare
    args: (optional) list of strings - arguments to apply to idd.py call
                                        refer to idd.py docs for more info

Ex.

idd(
    name = "name",
    image1 = "@<image1>//image",
    image2 = "hopefully_identical_image.tar",
    args = ["-v", "-d"]
)
"""

idd = rule(
    attrs = {
        "image1": attr.label(
            mandatory = True,
            allow_single_file = container_filetype,
        ),
        "image2": attr.label(
            mandatory = True,
            allow_single_file = container_filetype,
        ),
        "_idd_script": attr.label(
            default = ":idd",
            executable = True,
            allow_files = True,
            cfg = "host",
        ),
    },
    executable = True,
    implementation = _impl,
)
