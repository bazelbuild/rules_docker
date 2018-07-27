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
package(default_visibility = ["//visibility:public"])

load("//container:container.bzl", "container_image")
load("//contrib:test.bzl", "container_test")

container_test(
    name = "structure_test",
    configs = ["//tests/docker/configs:test.yaml"],
    image = "//testdata:link_with_files_base",
)

container_image(
    name = "deb_image_with_dpkgs",
    debs = [
        "//testdata:pkg1.deb",
        "//testdata:pkg2.deb",
        "//testdata:pkg_control_gz.deb",
        "//testdata:pkg_control_xz.deb",
        # TODO: (tejaldesai) Once we figure out how to selectively disable tests using build_tag_filters
        # ":busybox-static_ubuntu1_amd64.deb",
    ],
)

container_test(
    name = "deb_image_with_dpkgs_test",
    configs = ["//tests/docker/configs:deb_image_with_dpkgs.yaml"],
    image = ":deb_image_with_dpkgs",
)

container_image(
    name = "image_with_some_cmd_entrypoint",
    base = "@distroless_base//image",
    cmd = ["foo"],
    entrypoint = ["bar"],
)

container_test(
    name = "image_with_some_cmd_entrypoint_test",
    configs = ["//tests/docker/configs:image_with_some_cmd_entrypoint.yaml"],
    image = ":image_with_some_cmd_entrypoint",
)

container_image(
    name = "image_should_still_have_cmd_entrypoint",
    base = ":image_with_some_cmd_entrypoint",
)

container_test(
    name = "image_should_still_have_cmd_entrypoint_test",
    configs = ["//tests/docker/configs:image_with_some_cmd_entrypoint.yaml"],
    image = ":image_should_still_have_cmd_entrypoint",
)

container_image(
    name = "image_with_null_cmd_entrypoint",
    base = ":image_with_some_cmd_entrypoint",
    cmd = [],
    entrypoint = None,
)

container_test(
    name = "image_with_null_cmd_entrypoint_test",
    configs = ["//tests/docker/configs:image_with_null_cmd_entrypoint.yaml"],
    image = ":image_with_null_cmd_entrypoint",
)

container_image(
    name = "image_with_null_cmd_entrypoint_2",
    base = ":image_with_some_cmd_entrypoint",
    cmd = "",
    entrypoint = "",
)

container_test(
    name = "image_with_null_cmd_entrypoint_2_test",
    configs = ["//tests/docker/configs:image_with_null_cmd_entrypoint.yaml"],
    image = ":image_with_null_cmd_entrypoint_2",
)
