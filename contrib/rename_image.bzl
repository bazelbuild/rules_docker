# Copyright 2015 The Bazel Authors. All rights reserved.
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
"""A rule to rename the image from a <lang>_image or container_image target.

Migrated from https://github.com/GoogleContainerTools/base-images-docker/blob/4f2fc8da248a61c3f8e13bbb43e9db6c0ed44ba3/util/run.bzl#L264
"""

load("//container:bundle.bzl", "container_bundle")

def rename_image(name, image, new_repo, new_tag = "latest"):
    """
    A macro to predictably rename a given image.

    Args:
        name: A unique name for the rule, the output tarball is also ${name}.tar
        image: Label, representing the image to be renamed
        new_repo: String, new repo name to give to the image
        new_tag: String, new tag to give to the image

    Produces a tarball '${name}.tar' which contains the same image but now
    with the name '${new_repo}:${new_tag}'
    """

    new_image_name = new_repo + ":" + new_tag

    container_bundle(
        name = name,
        images = {
            new_image_name: image,
        },
    )

    return name + ".tar", new_image_name
