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

# Migrated from https://github.com/GoogleContainerTools/base-images-docker/blob/4f2fc8da248a61c3f8e13bbb43e9db6c0ed44ba3/util/run.bzl#L264

load("//container:bundle.bzl", "container_bundle")

def rename_image(image, name):
    """A macro to predictably rename the image under test."""
    intermediate_image_name = "%s:intermediate" % image.replace(":", "").replace("@", "").replace("/", "")
    image_tar_name = "intermediate_bundle_%s" % name

    # Give the image a predictable name when loaded
    container_bundle(
        name = image_tar_name,
        images = {
            intermediate_image_name: image,
        },
    )
    return image_tar_name, intermediate_image_name
