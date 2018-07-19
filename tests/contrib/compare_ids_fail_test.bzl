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

# Implementation of compare_ids_fail_test rule

def _impl(ctx):
    test_code = """ '
load("//:compare_ids_test.bzl", "compare_ids_test")

compare_ids_test(
    name = "test_for_failure",
    id = {id},
    images = {tars},
)
'
    """.format(
        id = repr(ctx.attr.id),
        # When linked, the tars will be placed into the base folder, and renamed 0.tar, 1.tar, ... etc
        tars = repr([str(i) + ".tar" for i in range(len(ctx.attr.images))]),
    )

    tar_files = []
    for tar in ctx.attr.images:
        tar_files += list(tar.files)

    tars_string = ""
    for tar_file in tar_files:
        tars_string += tar_file.short_path + " "

    runfiles = ctx.runfiles(files = tar_files + [
        ctx.file._compare_ids_test_bzl,
        ctx.file._compare_ids_test,
        ctx.file._extract_image_id,
        ctx.file._BUILD,
    ])

    # Produces string of form (Necessary because of spaces): " 'reg exp 1' 'reg exp 2'"
    reg_exps = ""
    if len(ctx.attr.reg_exps) > 0:
        reg_exps = "'" + "' '".join(ctx.attr.reg_exps) + "'"

    ctx.actions.expand_template(
        template = ctx.file._executable_template,
        output = ctx.outputs.executable,
        substitutions = {
            "{tars}": tars_string,
            "{test_code}": test_code,
            "{bzl_path}": ctx.file._compare_ids_test_bzl.short_path,
            "{test_bin_path}": ctx.file._compare_ids_test.short_path,
            "{extractor_path}": ctx.file._extract_image_id.short_path,
            "{name}": ctx.attr.name,
            "{reg_exps}": reg_exps,
            "{BUILD_path}": ctx.file._BUILD.short_path,
        },
        is_executable = True,
    )

    return [DefaultInfo(runfiles = runfiles)]

"""
Test to test correctness of failure cases of the compare_ids_test.

Args:
    images: List of Labels which refer to the docker image tarballs (from docker save)
    id: (optional) the id we want the images in the tarballs to have
    reg_exps: (optional) a list of regular expressions that must match the output text
        of the bazel call. (Ex [".*Executed .* fail.*"] makes sure the given test failed
        as opposed to failing to build)

This test passes only if the compare_ids_test it generates fails

Each tarball must contain exactly one image.

Examples of use:

compare_ids_fail_test(
    name = "test1",
    images = ["image.tar", "image_with_diff_id.tar"],
)

compare_ids_fail_test(
    name = "test2",
    images = ["image.tar"],
    id = "<my_wrong_image_sha256>",
)
"""
compare_ids_fail_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "images": attr.label_list(mandatory = True, allow_files = True),
        "id": attr.string(mandatory = False, default = ""),
        "reg_exps": attr.string_list(mandatory = False, default = []),
        "_executable_template": attr.label(
            allow_files = True,
            single_file = True,
            default = "compare_ids_fail_test.sh.tpl",
        ),
        "_compare_ids_test_bzl": attr.label(
            allow_files = True,
            single_file = True,
            default = "//contrib:compare_ids_test.bzl",
        ),
        "_compare_ids_test": attr.label(
            allow_files = True,
            single_file = True,
            default = "//contrib:compare_ids_test.py",
        ),
        "_extract_image_id": attr.label(
            allow_files = True,
            single_file = True,
            default = "//contrib:extract_image_id.py",
        ),
        "_BUILD": attr.label(
            allow_files = True,
            single_file = True,
            default = "//contrib:BUILD",
        ),
    },
)
