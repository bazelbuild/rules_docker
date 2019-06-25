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
"""Rule for importing an image from 'docker save' tarballs.

This extracts the tarball, examines the layers and creates a
container_import target for use with container_image.
"""

load(
    "//container:new_pull.bzl",
    "new_container_pull",
)

def _impl(repository_ctx):
    """Core implementation of new_container_load."""

    # Add an empty top-level BUILD file.
    repository_ctx.file("BUILD", "")

    repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "image",
    srcs = glob(["image/**"]),
)
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
            default = Label("@loader//:loader"),
            cfg = "host",
        )
    },
    implementation = _impl,
)
