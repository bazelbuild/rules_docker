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
"container_pull rule"

load("//internal:execution.bzl", "env_execute", "executable_extension")

_DOC = """A repository rule that pulls down a Docker base image in a manner suitable for use with the `base` attribute of `container_image`.

This is based on google/containerregistry using google/go-containerregistry.
It wraps the rulesdocker.go.cmd.puller.puller executable in a
Bazel rule for downloading base images without a Docker client to
construct new images.

NOTE: `container_pull` now supports authentication using custom docker client configuration.
See [here](https://github.com/bazelbuild/rules_docker#container_pull-custom-client-configuration) for details.

NOTE: Set `PULLER_TIMEOUT` env variable to change the default 600s timeout for all container_pull targets.

NOTE: Set `DOCKER_REPO_CACHE` env variable to make the container puller cache downloaded layers at the directory specified as a value to this env variable.
The caching feature hasn't been thoroughly tested and may be thread unsafe.
If you notice flakiness after enabling it, see the warning below on how to workaround it.

NOTE: `container_pull` is suspected to have thread safety issues.
To ensure multiple `container_pull`(s) don't execute concurrently,
please use the bazel startup flag `--loading_phase_threads=1` in your bazel invocation
(typically by adding `startup --loading_phase_threads=1` as a line in your `.bazelrc`)
"""

_container_pull_attrs = {
    "architecture": attr.string(
        default = "amd64",
        doc = "Which CPU architecture to pull if this image " +
              "refers to a multi-platform manifest list, default 'amd64'.",
    ),
    "cpu_variant": attr.string(
        doc = "Which CPU variant to pull if this image refers to a " +
              "multi-platform manifest list.",
    ),
    "digest": attr.string(
        doc = "The digest of the image to pull.",
    ),
    "docker_client_config": attr.label(
        doc = """Specifies  a Bazel label of the config.json file.

            Don't use this directly.
            Instead, specify the docker configuration directory using a custom docker toolchain configuration.
            Look for the `client_config` attribute in `docker_toolchain_configure`
            [here](https://github.com/bazelbuild/rules_docker#setup) for details.
            See [here](https://github.com/bazelbuild/rules_docker#container_pull-custom-client-configuration)
            for an example on how to use container_pull after configuring the docker toolchain

            When left unspecified (ie not set explicitly or set by the docker toolchain),
            docker will use the directory specified via the `DOCKER_CONFIG` environment variable.

            If `DOCKER_CONFIG` isn't set, docker falls back to `$HOME/.docker`.
            """,
        mandatory = False,
    ),
    "cred_helpers": attr.label_list(
        doc = """Labels to a list of credential helper binaries that are configured in `docker_client_config`.

        More about credential helpers: https://docs.docker.com/engine/reference/commandline/login/#credential-helpers
        """,
        mandatory = False,
    ),
    "import_tags": attr.string_list(
        default = [],
        doc = "Tags to be propagated to generated rules.",
    ),
    "os": attr.string(
        default = "linux",
        doc = "Which os to pull if this image refers to a multi-platform manifest list.",
    ),
    "os_features": attr.string_list(
        doc = "Specifies os features when pulling a multi-platform manifest list.",
    ),
    "os_version": attr.string(
        doc = "Which os version to pull if this image refers to a multi-platform manifest list.",
    ),
    "platform_features": attr.string_list(
        doc = "Specifies platform features when pulling a multi-platform manifest list.",
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
        doc = """The `tag` of the Docker image to pull from the specified `repository`.
        
        If neither this nor `digest` is specified, this attribute defaults to `latest`.
        If both are specified, then `tag` is ignored.

        Note: For reproducible builds, use of `digest` is recommended.
        """,
    ),
    "timeout": attr.int(
        doc = """Timeout in seconds to fetch the image from the registry.

        This attribute will be overridden by the PULLER_TIMEOUT environment variable, if it is set.""",
    ),
}

def _impl(repository_ctx):
    """Core implementation of container_pull."""

    # Add an empty top-level BUILD file.
    repository_ctx.file("BUILD", "")

    # Creating this empty just so `image` subfolder would exist
    repository_ctx.file("image/BUILD", "")

    import_rule_tags = "[\"{}\"]".format("\", \"".join(repository_ctx.attr.import_tags))

    puller = str(repository_ctx.path(Label("@rules_docker_repository_tools//:bin/puller{}".format(executable_extension(repository_ctx)))))
    args = [
        puller,
        "-directory",
        repository_ctx.path("image"),
        "-os",
        repository_ctx.attr.os,
        "-os-version",
        repository_ctx.attr.os_version,
        "-os-features",
        " ".join(repository_ctx.attr.os_features),
        "-architecture",
        repository_ctx.attr.architecture,
        "-variant",
        repository_ctx.attr.cpu_variant,
        "-features",
        " ".join(repository_ctx.attr.platform_features),
    ]

    # Use the custom docker client config directory if specified.
    docker_client_config = repository_ctx.attr.docker_client_config
    if docker_client_config:
        args += ["-client-config-dir", repository_ctx.path(docker_client_config).dirname]

    cache_dir = repository_ctx.os.environ.get("DOCKER_REPO_CACHE")
    if cache_dir:
        if cache_dir.startswith("~/") and "HOME" in repository_ctx.os.environ:
            cache_dir = cache_dir.replace("~", repository_ctx.os.environ["HOME"], 1)

        args += [
            "-cache",
            cache_dir,
        ]

    # If a digest is specified, then pull by digest.  Otherwise, pull by tag.
    if repository_ctx.attr.digest:
        args += [
            "-name",
            "{registry}/{repository}@{digest}".format(
                registry = repository_ctx.attr.registry,
                repository = repository_ctx.attr.repository,
                digest = repository_ctx.attr.digest,
            ),
        ]
    else:
        args += [
            "-name",
            "{registry}/{repository}:{tag}".format(
                registry = repository_ctx.attr.registry,
                repository = repository_ctx.attr.repository,
                tag = repository_ctx.attr.tag,
            ),
        ]

    kwargs = {}

    if "PULLER_TIMEOUT" in repository_ctx.os.environ:
        timeout_in_secs = repository_ctx.os.environ["PULLER_TIMEOUT"]
        if timeout_in_secs.isdigit():
            args += [
                "-timeout",
                timeout_in_secs,
            ]
            kwargs["timeout"] = int(timeout_in_secs)
        else:
            fail("'%s' is invalid value for PULLER_TIMEOUT. Must be an integer." % (timeout_in_secs))
    elif repository_ctx.attr.timeout > 0:
        args.extend(["-timeout", str(repository_ctx.attr.timeout)])
        kwargs["timeout"] = repository_ctx.attr.timeout

    if repository_ctx.attr.cred_helpers:
        kwargs["environment"] = {
            "PATH": "{}:{}".format(
                ":".join([str(repository_ctx.path(helper).dirname) for helper in repository_ctx.attr.cred_helpers]),
                repository_ctx.os.environ.get("PATH"),
            ),
        }

    env = {
        k: v
        for k, v in repository_ctx.os.environ.items()
        if k.lower() in (
            "home",

            # Unfortunately we explicitly need to pass along PATH. This prevents these CI failures:
            # https://buildkite-cloud.s3.amazonaws.com/logs-by-pipeline/975a9deb-b320-454c-bbbd-f48ff8715013/a909ba30-d7c1-4933-8967-b065cd26ada6/3627cc09-b972-4ef9-b016-1769b5f1bc1e.log?response-content-disposition=inline&response-content-type=text%2Fplain&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAQPCP3C7L5YYASYPJ%2F20210729%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20210729T213055Z&X-Amz-Expires=600&X-Amz-SignedHeaders=host&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEIz%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJGMEQCICqdixAGiKRYKDt8QoxMj7%2BIE4VZd5Rwb7B7CFJW9NfCAiBXkBktAUfAPq8cOenf6KF9kTc3PyhSw5TSHv7%2FSKhVEiqDBAiU%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAAaDDAzMjM3OTcwNTMwMyIMIiMXgpHDsdYY4RRAKtcDDszOZv8juVR38UnAiiD2vJ8h84KRTCElNivvtY%2BlQbvG%2BZi%2F%2F%2BPMfiiI%2FQux5hVtQxaXZ%2BUJd68NU9z5AebTBGhkdakldB2Req%2FrCvfiwX%2BMVu0utYhLyajesuNOK4NnT%2FI7sDWVbw0uUBejPhguOVvvCVBLiXkCFyja9JcW8A9flVag%2FKhkzKlzX6yUyLaFCmLD1POVSH6Q4lv9cELfEUaB7PRh%2FQOmaQFAshYILTpJaUaYVeVR5svHDF5757bX4KIxO56tYdm7gLkRRFpkLIl2r4t7jqgxMdJVTDi7qGLrqcREXlpWsDFSNpqf1h%2FPo7nRzp8rVHdTXR4jGcEVeErOS1pgcSeM5itZ2GTlEmTHrWurc9f3ObRslpE41AlPBlt7EaEBLIp%2Bro4rSl5lGBymM84Jmnc7aZ%2Bbm9qeORXJSnAiHJso08j8BvZYFQsMhC5vzboBXVA9jOFnIk8j8l6Wntn2f7WFJVCquALTWJRk6b3Sr5sprls4ziKYcNo5aF89587WuW14x8TCNWAFSr%2B7xlc%2FPoNynkrMnyNHZz3nhg47fBZ6NmBxhcGhIX%2BNICovHL%2B5jU7xUI6Np7%2BUQa1j7WoyIdwfulfd1gmS1ffCPpwCoRTVMMn%2Fi4gGOqYBU60X2DnTnnbCj%2BOuqPxUY8rIPArYmSjCnMhWkurutk43xD01CJijrS92WSMSpZ17mKE35ezJnYwcnD2tKULWhNEjuucai7SSeh1%2FrD%2BprREeVMNh3r8aaDZJ84BH0y1Qv0qV0DRB0if7puecit027w98NpH0I%2BEfSu2WsBhkOkcmHuqIqF0iNNx%2Bu292PQ3LtTM7qwMECzZLqgat%2FRV%2BeJ61hxVsgw%3D%3D&X-Amz-Signature=19b6022f09bafab8b72b9ec16bd970af72328d1aafe4303f93a1dcd3540c73ef
            # TODO(gravypod): Find out how to avoid needing to do this. Might need to refactor puller.
            "path",

            # Only allow environment variables that influence the pusher through.
            "ssh_auth_sock",
            "ssl_cert_file",
            "ssl_cert_dir",
            "http_proxy",
            "https_proxy",
            "no_proxy",
        )
    }

    result = env_execute(repository_ctx, args, environment = env, **kwargs)
    if result.return_code:
        fail("Pull command failed: %s (%s)" % (result.stderr, " ".join([str(a) for a in args])))

    updated_attrs = {
        k: getattr(repository_ctx.attr, k)
        for k in _container_pull_attrs.keys()
    }
    updated_attrs["name"] = repository_ctx.name

    updated_attrs["digest"] = repository_ctx.read(repository_ctx.path("image/digest"))

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

    repository_ctx.file("image/BUILD", """package(default_visibility = ["//visibility:public"])
load("@io_bazel_rules_docker//container:import.bzl", "container_import")

container_import(
    name = "image",
    config = "config.json",
    layers = glob(["*.tar.gz"]),
    base_image_registry = "{registry}",
    base_image_repository = "{repository}",
    base_image_digest = "{digest}",
    tags = {tags},
)

exports_files(["image.digest", "digest"])
""".format(
        registry = updated_attrs["registry"],
        repository = updated_attrs["repository"],
        digest = updated_attrs["digest"],
        tags = import_rule_tags,
    ))
    return updated_attrs

pull = struct(
    attrs = _container_pull_attrs,
    implementation = _impl,
)

# Pulls a container image.

# This rule pulls a container image into our intermediate format (OCI Image Layout).
container_pull = repository_rule(
    doc = _DOC,
    attrs = _container_pull_attrs,
    implementation = _impl,
    environ = [
        "DOCKER_REPO_CACHE",
        "HOME",
        "PULLER_TIMEOUT",
    ],
)
