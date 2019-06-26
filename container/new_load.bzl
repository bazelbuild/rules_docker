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
"""Rule for loading an image from 'docker save' tarball or the current 
   container_pull tarball format into OCI intermediate layout.

This extracts the tarball amd creates a filegroup of the untarred objects in OCI layout.
"""

def _impl(repository_ctx):
    """Core implementation of new_container_load."""

    # Add an empty top-level BUILD file.
    repository_ctx.file("BUILD", "")

    repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])

# TODO(xwinxu): this will be changed to new_container_import once that is implemented later
# similar to what we have in new_pull.bzl

filegroup(
    name = "image",
    srcs = glob(["image/**"]),
)
exports_files(glob(["**"]))
""", executable = False)

    result = repository_ctx.execute([
        repository_ctx.path(repository_ctx.attr._loader),
        "-directory",
        repository_ctx.path("image"),
        "-tarball",
        repository_ctx.path(repository_ctx.attr.file),
    ])

    if result.return_code:
        fail("Importing from tarball failed (status %s): %s" % (result.return_code, result.stderr))

new_container_load = repository_rule(
    attrs = {
        "file": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "_loader": attr.label(
            executable = True,
            default = Label("@loader//file:downloaded"),
            cfg = "host",
        ),
    },
    implementation = _impl,
)
