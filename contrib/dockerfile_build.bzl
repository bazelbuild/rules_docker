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

This rule uses the docker tool installed in the system to build the image and
then save it as a tar file. The saved tar file is available for other rules to
use (e.g. container_image, container_load, container_test)

The built docker image is always called after the dockerfile_image target used
to build the image and tagged with `dockerfile_image` (i.e. <target_name>:dockerfile_image).
This means that if an image with name <target_name>:dockerfile_image already
exists and a dockerfile_image target called <target_name> is built, then the
existing image will change its name to <none>:<none> and the newly built image
will get the <target_name>:dockerfile_image name.

The produced tar file is available at @<repo_name>//image:dockerfile_image.tar
"""

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

    docker_path = _docker(repository_ctx)

    dockerfile_path = repository_ctx.path(repository_ctx.attr.dockerfile)
    img_name = repository_ctx.name + ":dockerfile_image"

    # The docker bulid command needs to run using the supplied Dockerfile
    # because it may refer to relative paths in its ADD, COPY and WORKDIR
    # instructions.
    build_args = [
        docker_path,
        "build",
        "--no-cache",
        "-f",
        dockerfile_path,
        "-t",
        img_name,
        dockerfile_path.dirname,
    ]
    build_result = repository_ctx.execute(build_args)
    if build_result.return_code:
        fail("docker build command failed: {} ({})".format(
            build_result.stderr,
            " ".join(build_args),
        ))

    image_tar = "dockerfile_image.tar"
    repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])

exports_files(["{}"])
""".format(image_tar))

    save_result = repository_ctx.execute([
        docker_path,
        "save",
        "-o",
        "image/" + image_tar,
        img_name,
    ])
    if save_result.return_code:
        fail("docker save command failed for image {}: {}".format(
            img_name,
            save_result.stderr,
        ))

dockerfile_image = repository_rule(
    attrs = {
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
    },
    implementation = _impl,
)
