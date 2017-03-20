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
"""An implementation of docker_pull based on google/containerregistry.

This wraps the containerregistry.tools.docker_puller executable in a
Bazel rule for downloading base images without a Docker client to
construct new images with docker_build.
"""


def _impl(repository_ctx):
  """Core implementation of docker_pull."""
  # Add an empty top-level BUILD file.
  repository_ctx.file("BUILD", "")

  # If a digest is specified, then pull by digest.  Otherwise, pull by tag.
  # We do this in a directory named image (with a BUILD target image), so
  # that users can reference: @foo//image
  if repository_ctx.attr.digest:
    # TODO(mattmoor): Update this once we've released a version that supports
    # pulling by digest.
    fail("docker_puller doesn't yet support pulling digests.")
    # repository_ctx.template(
    #     "image/BUILD", repository_ctx.path(repository_ctx.attr._digest_tpl),
    #     substitutions={
    #         "%{registry}": repository_ctx.attr.registry,
    #         "%{repository}": repository_ctx.attr.repository,
    #         "%{digest}": repository_ctx.attr.digest
    #     }, executable=False)
  else:
    repository_ctx.template(
        "image/BUILD", repository_ctx.path(repository_ctx.attr._tag_tpl),
        substitutions={
            "%{registry}": repository_ctx.attr.registry,
            "%{repository}": repository_ctx.attr.repository,
            "%{tag}": repository_ctx.attr.tag
        }, executable=False)


_docker_pull = repository_rule(
    implementation = _impl,
    attrs = {
        "registry": attr.string(mandatory=True),
        "repository": attr.string(mandatory=True),
        "digest": attr.string(),
        "tag": attr.string(default="latest"),
        "_tag_tpl": attr.label(
            default=Label("//docker:pull-tag.BUILD.tpl"),
            cfg="host",
            allow_files=True),
        "_digest_tpl": attr.label(
            default=Label("//docker:pull-digest.BUILD.tpl"),
            cfg="host",
            allow_files=True),
    },
)


def docker_pull(**kwargs):
  """Pulls a docker image.

  This rule pulls a docker image into the 'docker save' format.  The
  output of this rule can be used interchangeably with `docker_build`.
  Args:
    name: name of the rule
    registry: the registry from which we are pulling.
    repository: the name of the image.
    tag: (optional) the tag of the image, default to 'latest' if this
         and 'digest' remain unspecified.
    digest: (optional) the digest of the image to pull.
  """
  _docker_pull(**kwargs)
