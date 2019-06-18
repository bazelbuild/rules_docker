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
"""An implementation of container_pull based on google/containerregistry.

This wraps the containerregistry.tools.fast_puller executable in a
Bazel rule for downloading base images without a Docker client to
construct new images.
"""

def python(repository_ctx):
    """Resolves the python path.

    Args:
      repository_ctx: The repository context

    Returns:
      The path to the python interpreter
    """

    if "BAZEL_PYTHON" in repository_ctx.os.environ:
        return repository_ctx.os.environ.get("BAZEL_PYTHON")

    python_path = repository_ctx.which("python2")
    if not python_path:
        python_path = repository_ctx.which("python")
    if not python_path:
        python_path = repository_ctx.which("python.exe")
    if python_path:
        return python_path

    fail("rules_docker requires a python interpreter installed. " +
         "Please set BAZEL_PYTHON, or put it on your path.")

_container_pull_attrs = {
    "architecture": attr.string(
        default = "amd64",
        doc = "(optional) Which CPU architecture to pull if this image " +
              "refers to a multi-platform manifest list, default 'amd64'.",
    ),
    "cpu_variant": attr.string(
        doc = "Which CPU variant to pull if this image refers to a " +
              "multi-platform manifest list.",
    ),
    "digest": attr.string(
        doc = "(optional) The digest of the image to pull.",
    ),
    "docker_client_config": attr.string(
        doc = "A custom directory for the docker client config.json. " +
              "If DOCKER_CONFIG is not specified, the value of the " +
              "DOCKER_CONFIG environment variable will be used. DOCKER_CONFIG" +
              " is not defined, the home directory will be used.",
        mandatory = False,
    ),
    "os": attr.string(
        default = "linux",
        doc = "(optional) Which os to pull if this image refers to a " +
              "multi-platform manifest list, default 'linux'.",
    ),
    "os_features": attr.string_list(
        doc = "(optional) Specifies os features when pulling a multi-platform " +
              "manifest list.",
    ),
    "os_version": attr.string(
        doc = "(optional) Which os version to pull if this image refers to a " +
              "multi-platform manifest list.",
    ),
    "platform_features": attr.string_list(
        doc = "(optional) Specifies platform features when pulling a " +
              "multi-platform manifest list.",
    ),
    "registry": attr.string(
        mandatory = True,
        doc = "The registry from which we are pulling.",
    ),
    "repository": attr.string(
        mandatory = True,
        doc = "The name of the image.",
    ),
    "tag": attr.string(
        default = "latest",
        doc = "(optional) The tag of the image, default to 'latest' " +
              "if this and 'digest' remain unspecified.",
    ),
    "_puller": attr.label(
        executable = True,
        default = Label("@puller//file:downloaded"),
        cfg = "host",
    ),
}

def _impl(repository_ctx):
    """Implementation of container_pull."""

    # Add an empty top-level BUILD file.
    repository_ctx.file("BUILD", "")

    repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_docker//container:import.bzl", "container_import")

container_import(
  name = "image",
  config = "config.json",
  layers = glob(["*.tar.gz"]),
)

exports_files(["image.digest", "digest"])
""")

    args = [
        python(repository_ctx),
        repository_ctx.path(repository_ctx.attr._puller),
        "--directory",
        repository_ctx.path("image"),
        "--os",
        repository_ctx.attr.os,
        "--os-version",
        repository_ctx.attr.os_version,
        "--os-features",
        " ".join(repository_ctx.attr.os_features),
        "--architecture",
        repository_ctx.attr.architecture,
        "--variant",
        repository_ctx.attr.cpu_variant,
        "--features",
        " ".join(repository_ctx.attr.platform_features),
    ]

    # Use the custom docker client config directory if specified.
    if repository_ctx.attr.docker_client_config != "":
        args += ["--client-config-dir", "{}".format(repository_ctx.attr.docker_client_config)]

    cache_dir = repository_ctx.os.environ.get("DOCKER_REPO_CACHE")
    if cache_dir:
        if cache_dir.startswith("~/") and "HOME" in repository_ctx.os.environ:
            cache_dir = cache_dir.replace("~", repository_ctx.os.environ["HOME"], 1)

        args += [
            "--cache",
            cache_dir,
        ]

    # If a digest is specified, then pull by digest.  Otherwise, pull by tag.
    if repository_ctx.attr.digest:
        args += [
            "--name",
            "{registry}/{repository}@{digest}".format(
                registry = repository_ctx.attr.registry,
                repository = repository_ctx.attr.repository,
                digest = repository_ctx.attr.digest,
            ),
        ]
    else:
        args += [
            "--name",
            "{registry}/{repository}:{tag}".format(
                registry = repository_ctx.attr.registry,
                repository = repository_ctx.attr.repository,
                tag = repository_ctx.attr.tag,
            ),
        ]

    kwargs = {}
    if "PULLER_TIMEOUT" in repository_ctx.os.environ:
        kwargs["timeout"] = int(repository_ctx.os.environ.get("PULLER_TIMEOUT"))

    result = repository_ctx.execute(args, **kwargs)
    if result.return_code:
        fail("Pull command failed: %s (%s)" % (result.stderr, " ".join([str(a) for a in args])))

    updated_attrs = {
        k: getattr(repository_ctx.attr, k)
        for k in _container_pull_attrs.keys()
    }
    updated_attrs["name"] = repository_ctx.name

    digest_result = repository_ctx.execute(["cat", repository_ctx.path("image/digest")])
    if digest_result.return_code:
        fail("Failed to read digest: %s" % digest_result.stderr)
    updated_attrs["digest"] = digest_result.stdout

    if repository_ctx.attr.digest and repository_ctx.attr.digest != updated_attrs["digest"]:
        fail(("SHA256 of the image specified does not match SHA256 of the pulled image. " +
              "Expected {}, but pulled image with {}. " +
              "It is possible that you have a pin to a manifest list " +
              "which points to another image, if so, " +
              "change the pin to point at the actual Docker image").format(
            repository_ctx.attr.digest,
            updated_attrs["digest"],
        ))

    # Add image.digest for compatibility with container_digest, which generates
    # foo.digest for an image named foo.
    repository_ctx.symlink(repository_ctx.path("image/digest"), repository_ctx.path("image/image.digest"))

    return updated_attrs

pull = struct(
    attrs = _container_pull_attrs,
    implementation = _impl,
)

# Pulls a container image.

# This rule pulls a container image into our intermediate format.  The
# output of this rule can be used interchangeably with `docker_build`.
container_pull = repository_rule(
    attrs = _container_pull_attrs,
    implementation = _impl,
    environ = [
        "DOCKER_REPO_CACHE",
        "HOME",
        "PULLER_TIMEOUT",
    ],
)
