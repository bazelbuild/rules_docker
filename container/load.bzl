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
    "//container:pull.bzl",
    _python = "python",
)

def _impl(repository_ctx):
    """Core implementation of container_load."""

    # Add an empty top-level BUILD file.
    repository_ctx.file("BUILD", "")

    repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_docker//container:import.bzl", "container_import")

container_import(
  name = "image",
  config = "config.json",
  layers = glob(["*.tar"]),
)
""", executable = False)

    result = repository_ctx.execute([
        _python(repository_ctx),
        repository_ctx.path(repository_ctx.attr._importer),
        "--directory",
        repository_ctx.path("image"),
        "--tarball",
        repository_ctx.path(repository_ctx.attr.file),
    ])

    if result.return_code:
        fail("Importing from tarball failed (status %s): %s" % (result.return_code, result.stderr))

container_load = repository_rule(
    attrs = {
        "file": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "_importer": attr.label(
            executable = True,
            default = Label("@importer//file:downloaded"),
            cfg = "host",
        ),
    },
    implementation = _impl,
)
