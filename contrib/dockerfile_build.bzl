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

"""Repository rule for building a Docker image from a Dockerfile and saving it
   into a tar file.

This rule uses either the docker tool installed in the system or the Kaniko
executor container to build the image and then save it as a tar file.
The saved tar file is available for other rules to use (e.g. container_image,
container_load, container_test)

The built docker image is always called after the dockerfile_image target used
to build the image and tagged with `dockerfile_image` (i.e. <target_name>:dockerfile_image).
This means that if an image with name <target_name>:dockerfile_image already
exists and a dockerfile_image target called <target_name> is built, then the
existing image will change its name to <none>:<none> and the newly built image
will get the <target_name>:dockerfile_image name.

The produced tar file is available at @<repo_name>//image:dockerfile_image.tar
"""

_KANIKO_IMAGE_PATH = "gcr.io/kaniko-project/executor"
_KANIKO_WORKSPACE_DIR = "/workspace"
_OUTPUT_IMAGE_TAR = "dockerfile_image.tar"

def _docker(repository_ctx):
    """Resolves the docker path.

    Args:
      repository_ctx: The repository context

    Returns:
      Tha path to the docker tool
    """

    if repository_ctx.attr.docker_path:
        return repository_ctx.attr.docker_path
    if repository_ctx.which("docker"):
        return str(repository_ctx.which("docker"))

    fail("Path to the docker tool was not provided and it could not be resolved automatically.")

def _impl(repository_ctx):
    """Core implementation of dockerfile_image."""

    # Create the BUILD file.
    repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])

exports_files(["{}"])
""".format(_OUTPUT_IMAGE_TAR))

    docker_path = _docker(repository_ctx)
    dockerfile_path = repository_ctx.path(repository_ctx.attr.dockerfile)
    img_name = repository_ctx.name + ":dockerfile_image"

    build_args = []
    if repository_ctx.attr.build_args:
        for pair in repository_ctx.attr.build_args.items():
            build_args.extend(["--build-arg", "%s=%s" % (pair[0], pair[1])])

    if repository_ctx.attr.driver == "docker":
        command = [docker_path, "build"]
        command.extend(build_args)
        command.extend([
            "--no-cache",
            # The docker bulid command needs to run using the supplied Dockerfile
            # because it may refer to relative paths in its ADD, COPY and WORKDIR
            # instructions.
            "-f",
            str(dockerfile_path),
            "-t",
            img_name,
            str(dockerfile_path.dirname),
        ])

        build_result = repository_ctx.execute(command)
        if build_result.return_code:
            fail("Image build command failed: {} ({})".format(
                build_result.stdout + build_result.stderr,
                " ".join(command),
            ))

        save_result = repository_ctx.execute([
            docker_path,
            "save",
            "-o",
            "image/" + _OUTPUT_IMAGE_TAR,
            img_name,
        ])
        if save_result.return_code:
            fail("docker save command failed for image {}: {}".format(
                img_name,
                save_result.stderr,
            ))

    elif repository_ctx.attr.driver == "kaniko":
        # Additional kaniko options.
        kaniko_flags = [
            # Path to Dockerfile within the build context.
            "--dockerfile=Dockerfile",
            # Image tag.
            "-d",
            img_name,
            # Strip timestamps.
            "--reproducible",
            "--no-push",
        ]

        template = repository_ctx.path(Label("@io_bazel_rules_docker//contrib:kaniko_run_and_extract.sh.tpl"))
        repository_ctx.template(
            "kaniko_run_and_extract.sh",
            template,
            {
                "%{build_context_dir}": str(dockerfile_path.dirname),
                "%{docker_path}": docker_path,
                "%{extract_file}": "/%s" % _OUTPUT_IMAGE_TAR,
                "%{image_path}": repository_ctx.attr.kaniko_image_path,
                "%{kaniko_flags}": " ".join(kaniko_flags),
                "%{kaniko_workspace}": _KANIKO_WORKSPACE_DIR,
                "%{output}": "%s/%s" % (repository_ctx.path("image"), _OUTPUT_IMAGE_TAR),
            },
            True,
        )

        build_result = repository_ctx.execute(["./kaniko_run_and_extract.sh"])
        if build_result.return_code:
            fail("Image build command failed: {}".format(
                build_result.stderr,
            ))

    else:
        # Should not hit here.
        fail("Driver `%s` is not supported." % repository_ctx.attr.driver)

_dockerfile_image = repository_rule(
    attrs = {
        "build_args": attr.string_dict(
            doc = "A map of args to pass to the --build-arg option in the " +
                  "docker or kaniko build command.",
        ),
        "docker_path": attr.string(
            doc = "The full path to the docker binary. If not specified, it " +
                  "will be searched for in the path. If not available, " +
                  "the rule build will fail.",
        ),
        "dockerfile": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The label for the Dockerfile to build the image from.",
        ),
        "driver": attr.string(
            mandatory = True,
            doc = "The image building tool to use. Currently, `docker` and " +
                  "`kaniko` are supported.",
        ),
        "kaniko_image_path": attr.string(
            mandatory = True,
            doc = "Set by dockerfile_image macro. The full image path of the " +
                  "kaniko executor image to use to build the output image. " +
                  "This should not be set by users directly.",
        ),
    },
    implementation = _impl,
)

def dockerfile_image(
        name,
        dockerfile,
        build_args = None,
        docker_path = None,
        driver = "docker",
        kaniko_digest = None,
        kaniko_tag = None):
    """ Creates a repository with a docker tarball generated from Dockerfile.

    This macro wraps (and simplifies) invocation of _dockerfile_image rule.
    Use this macro in your WORKSPACE.

    Args:
      name: Name of the dockerfile_image repository target.
      dockerfile: The label for the Dockerfile to build the image from.
      build_args: A map of args to pass to the --build-arg option in the docker
            or kaniko build command.
      docker_path: Specifies the full path to the docker binary. If not
            specified, it will be searched for in the path. If not available,
            the rule will fail. This is needed even when the driver is `kaniko`
            as docker is needed to run the kaniko executor image.
      driver: The image building tool to use. Currently, `docker` and `kaniko`
            are supported. Default to `docker`.
            Note that not all features in Dockerfile are supported by kaniko,
            which means a Dockerfile might work with docker, but not with
            kaniko. For example, ARG replacement in ADD is not supported in
            kaniko.
      kaniko_digest: If driver is `kaniko`, specifies the digest of the kaniko
            executor image (in the format of sha256:xxx) to use to build the
            image.
            Cannot be set if driver is `docker` or kaniko_tag is set.
      kaniko_tag: If driver is `kaniko`, speficies the tag of the kaniko
            executor image to use to build the image.
            Cannot be set if driver is `docker` or kaniko_digest is set.
    """
    if driver != "docker" and driver != "kaniko":
        fail("Driver can only be `docker` or `kaniko`.")

    if driver == "docker" and (kaniko_digest or kaniko_tag):
        fail("kaniko_digest or kaniko_tag should not be set when driver is `docker`.")

    if kaniko_digest and kaniko_tag:
        fail("kaniko_digest and kaniko_tag should not be set at the same time.")

    if kaniko_digest and not kaniko_digest.startswith("sha256:"):
        fail("kanoko_digest must start with 'sha256:'.")

    kaniko_image_path = _KANIKO_IMAGE_PATH
    if kaniko_digest:
        kaniko_image_path = _KANIKO_IMAGE_PATH + "@" + kaniko_digest
    if kaniko_tag:
        kaniko_image_path = _KANIKO_IMAGE_PATH + ":" + kaniko_tag

    _dockerfile_image(
        name = name,
        build_args = build_args,
        docker_path = docker_path,
        dockerfile = dockerfile,
        driver = driver,
        kaniko_image_path = kaniko_image_path,
    )
