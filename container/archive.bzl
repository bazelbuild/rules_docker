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

def _container_archive_impl(ctx):
  result = ctx.execute([
      ctx.path(ctx.attr._importer),
      "--directory", ".",
      "--tarball", ctx.path(ctx.attr.file)])

  if result.return_code:
    fail("Importing from tarball failed (status %s): %s" % (result.return_code, result.stderr))

  ctx.file("BUILD", """
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_docker//container:import.bzl", "container_import")

container_import(
  name = \"""" + ctx.attr.image_tag + """\",
  config = "config.json",
  layers = glob(["*.tar.gz"]),
  repository = \"""" + ctx.attr.image_repository + """\",
)
""", executable=False)

container_archive = repository_rule(
    attrs = {
        "file": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "image_repository": attr.string(default = "bazel"),
        "image_tag": attr.string(default = "image"),
        "_importer": attr.label(
            executable = True,
            default = Label("@importer//file:importer.par"),
            cfg = "host",
        ),
    },
    implementation = _container_archive_impl,
)
