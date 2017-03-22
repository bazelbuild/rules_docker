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

  # TODO(mattmoor): Is there a way of doing this so that
  # consumers can just depend on @base//image ?
  repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])
exports_files(["image.tar"])
""")

  args = [
      repository_ctx.path(repository_ctx.attr._puller),
      "--tarball", repository_ctx.path("image/image.tar")
  ]

  # If a digest is specified, then pull by digest.  Otherwise, pull by tag.
  if repository_ctx.attr.digest:
    args += [
        "--name", "{registry}/{repository}@{digest}".format(
            registry=repository_ctx.attr.registry,
            repository=repository_ctx.attr.repository,
            digest=repository_ctx.attr.digest)
    ]
  else:
    args += [
        "--name", "{registry}/{repository}:{tag}".format(
            registry=repository_ctx.attr.registry,
            repository=repository_ctx.attr.repository,
            tag=repository_ctx.attr.tag)
    ]

  result = repository_ctx.execute(args)
  if result.return_code:
    fail("Pull command failed: %s (%s)" % (result.stderr, " ".join(args)))


_docker_pull = repository_rule(
    implementation = _impl,
    attrs = {
        "registry": attr.string(mandatory=True),
        "repository": attr.string(mandatory=True),
        "digest": attr.string(),
        "tag": attr.string(default="latest"),
        "_puller": attr.label(
          executable=True,
          default=Label("@puller//file:puller.par"),
          cfg="host",
        ),
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
