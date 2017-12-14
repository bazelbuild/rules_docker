# Copyright 2016 The Bazel Authors. All rights reserved.
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

"""Repository rule to build image with `docker build`."""

def _impl(rctx):
  tag = rctx.attr.tag
  dockerfile = rctx.path(rctx.attr.dockerfile)
  result = rctx.execute([
      "docker",
      "build",
      "-q",
      "-t",
      tag,
      "-f",
      dockerfile,
      dockerfile.dirname,
  ])
  if result.return_code:
    fail("docker build failed with error code %s:\n%s" % (
        result.return_code,
        result.stdout + result.stderr))
  base_tar = rctx.path("base.tar")
  base_dir = rctx.path("base")
  result = rctx.execute(["docker", "save", "-o", base_tar, tag])
  if result.return_code:
    fail("docker save failed with error code %s:\n%s" % (
        result.return_code,
        result.stderr))
  result = rctx.execute(["python", rctx.path(Label("//contrib:convert_image_to_build.py")),
                         base_tar, base_dir, rctx.path("BUILD")])
  if result.return_code:
    fail("Converting the image failed with error code %s:\n%s" % (
        result.return_code,
        result.stderr))

"""
Workspace rule to use docker to build a dockerfile and return a docker_build compatible image.

Params:
  tag: tag to name the image inside docker
  dockerfile: label of the dockerfile to use to build the image

Returns:
  @name//:image: a docker_import target that contains the builded image.
"""

dockerfile_build = repository_rule(
    attrs = {
        "tag": attr.string(mandatory = True),
        "dockerfile": attr.label(mandatory = True),
    },
    implementation = _impl,
)
