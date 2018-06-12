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

#Implementation of compare_ids_test
def _compare_ids_test_impl(ctx):
    tar_files = []
    for tar in ctx.attr.tars:
        tar_files += list(tar.files)

    if (len(tar_files) == 0):
        fail("No tar files provided for test.")

    if (len(tar_files) == 1 and ctx.attr.id == "0"):
        fail("One tar provided. Need either second tar or an id to compare it to.")

    tars_string = ""
    for tar in tar_files:
        tars_string += tar.path + " "

    runfiles = ctx.runfiles(files = tar_files)

    ctx.actions.expand_template(
        template = ctx.file._executable_template,
        output = ctx.outputs.executable,
        substitutions = {"{id}": ctx.attr.id, "{tars}": tars_string},
        is_executable = True,
    )

    return [DefaultInfo(runfiles = runfiles)]

"""
Test to help with maintaining reproducibility.

Args:
    tars: List of Labels which refer to the tarballs
    id: (optional) the id we want the tarballs to have

The test passes if all tarballs have the given id.
The test also passes if no id is provided and all tarballs have the same id.
"""
compare_ids_test = rule(
    implementation = _compare_ids_test_impl,
    test = True,
    attrs = {
        "tars": attr.label_list(mandatory = True, allow_files = True),
        "id": attr.string(mandatory = False, default = "0"),
        "_executable_template": attr.label(
            allow_files = True,
            single_file = True,
            default = "compare_ids_test.sh.tpl",
        ),
    },
)
