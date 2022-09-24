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
"""Test to compare ids of images in tarballs.

Useful for testing reproducibility.

Args:
    images: List of Labels which refer to the docker image tarballs (from docker save)
    id: (optional) the id we want the images in the tarballs to have

The test passes if all images in the tarballs have the given id.
The test also passes if no id is provided and all tarballs have the same id.

Each tarball must contain exactly one image.

Examples of use:

compare_ids_test(
    name = "test1",
    images = ["image1.tar", "image2.tar", "image3.tar"],
)

compare_ids_test(
    name = "test2",
    images = ["image.tar"],
    id = "<my_image_sha256>",
)
"""

# Implementation of compare_ids_test
def _compare_ids_test_impl(ctx):
    tar_files = []
    for file in ctx.files.images:
        if file.short_path.endswith("tar"):
            tar_files.append(file)

    if (len(tar_files) == 0):
        fail("No images provided for test.")

    if (len(tar_files) == 1 and not ctx.attr.id):
        fail("One tar provided. Need either second tar or an id to compare it to.")

    runfiles = ctx.runfiles(
        files = tar_files,
        transitive_files = ctx.attr._compare_ids_test_script[DefaultInfo].data_runfiles.files,
    )

    id_args = []
    if ctx.attr.id:
        id_args = ["--id", ctx.attr.id]

    args = " ".join([f.short_path for f in tar_files] + id_args)

    ctx.actions.write(
        output = ctx.outputs.executable,
        content = "python {} {}".format(ctx.executable._compare_ids_test_script.short_path, args),
        is_executable = True,
    )

    return [DefaultInfo(runfiles = runfiles)]

compare_ids_test = rule(
    attrs = {
        "id": attr.string(
            mandatory = False,
            default = "",
        ),
        "images": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "_compare_ids_test_script": attr.label(
            allow_files = True,
            default = ":compare_ids_test",
            executable = True,
            cfg = "host",
        ),
    },
    test = True,
    implementation = _compare_ids_test_impl,
)
