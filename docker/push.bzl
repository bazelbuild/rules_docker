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
"""An implementation of docker_push based on google/containerregistry.

This wraps the containerregistry.tools.docker_pusher executable in a
Bazel rule for publishing base images without a Docker client.
"""

def _impl(ctx):
  """Core implementation of docker_push."""

  ctx.template_action(
      template = ctx.file._tag_tpl,
      substitutions = {
          "%{registry}": ctx.expand_make_variables(
              "registry", ctx.attr.registry, {}),
          "%{repository}": ctx.expand_make_variables(
              "repository", ctx.attr.repository, {}),
          "%{tag}": ctx.expand_make_variables(
              "tag", ctx.attr.tag, {}),
          "%{image}": ctx.file.image.short_path,
          "%{docker_pusher}": ctx.executable._pusher.short_path,
      },
      output = ctx.outputs.executable,
      executable=True,
  )

  return struct(runfiles = ctx.runfiles(files = [
      ctx.file.image,
      ctx.executable._pusher
  ]))

_docker_push = rule(
    attrs = {
        "image": attr.label(
            allow_files = [".tar"],
            single_file = True,
        ),
        "registry": attr.string(mandatory = True),
        "repository": attr.string(mandatory = True),
        "tag": attr.string(default = "latest"),
        "_tag_tpl": attr.label(
            default = Label("//docker:push-tag.sh.tpl"),
            single_file = True,
            allow_files = True,
        ),
        "_pusher": attr.label(
            default = Label("@pusher//file"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    },
    executable = True,
    implementation = _impl,
)

def docker_push(image=None, **kwargs):
  """Pushes a docker image.

  This rule pushes a docker image to a Docker registry.

  Args:
    name: name of the rule
    image: the label of the image to push.
    registry: the registry to which we are pushing.
    repository: the name of the image.
    tag: (optional) the tag of the image, default to 'latest'.
  """

  if not image.endswith(".tar"):
    image = image + ".tar"

  _docker_push(image=image, **kwargs)
