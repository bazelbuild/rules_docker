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

def _impl(ctx):
  """Implementation of docker_diff."""

  image_location = ctx.executable.image.short_path
  cd_binary_loction = ctx.executable._container_diff_tool.short_path
  
  content = "%s diff %s %s" % (cd_binary_loction, image_location, ctx.attr.diff_base)
  if ctx.attr.diff_types:
    content += " --types=%s" % (",".join(ctx.attr.diff_types))
  
  ctx.file_action(
      output = ctx.outputs.executable,
      content = content,
  )

  return struct(runfiles=ctx.runfiles(
    files = [
      ctx.executable._container_diff_tool,
      ctx.executable.image
    ]),
  )

_docker_diff = rule(
    attrs = {
        "image": attr.label(
            allow_files = [".tar"],
            single_file = True,
            mandatory = True,
            executable = True,
            cfg = "target"
        ),
        "diff_base": attr.string(mandatory = True),
        "diff_types": attr.string_list(
          allow_empty = True,
        ),
        "_container_diff_tool": attr.label(
          default = Label("@container_diff//:container-diff"),
          executable = True,
          cfg = "host"
        ),
    },
    implementation = _impl,
    executable = True,
)

def docker_diff(image=None, **kwargs):
  """Diffs an image in bazel against in image in production .

  This rule runs container-diff on the two images and prints the output.

  Args:
    name: name of the rule
    image: bazel target to an image you have bazel built (must be a tar)
    diff_base: Tag or digest in a remote registry you want to diff against
    diff_types: Types to pass to container diff 
  """
  _docker_diff(image=image, **kwargs)
