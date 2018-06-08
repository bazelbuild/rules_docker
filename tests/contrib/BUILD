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

load("//contrib:rename_image.bzl", "rename_image")

sh_test(
    name = "rename_image_test",
    srcs = ["rename_image_test.sh"],
    data = [
        ":renamed_image.tar",
        "//contrib:extract_image_name.sh",
    ],
)

rename_image(
    name = "renamed_image",
    image = "@distroless_base//image",
    new_repo = "new_image_repo",
    new_tag = "new_image_tag",
)
