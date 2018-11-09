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

load("//container:container.bzl", "container_image", "container_import")
load("//contrib:test.bzl", "container_test")
load(
    "@bazel_tools//tools/build_rules:test_rules.bzl",
    "file_test",
)
load("//java:image.bzl", "java_image")

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
    name = "set_cmd",
    base = "@distroless_fixed_id//image",
    cmd = ["foo"],
)

container_test(
    name = "set_cmd_test",
    configs = ["//tests/docker/configs:set_cmd.yaml"],
    image = ":set_cmd",
)

container_image(
    name = "set_entrypoint",
    base = "@distroless_fixed_id//image",
    entrypoint = ["bar"],
)

container_test(
    name = "set_entrypoint_test",
    configs = ["//tests/docker/configs:set_entrypoint.yaml"],
    image = ":set_entrypoint",
)

container_image(
    name = "set_cmd_and_entrypoint",
    base = "@distroless_fixed_id//image",
    cmd = ["foo"],
    entrypoint = ["bar"],
)

container_test(
    name = "set_cmd_and_entrypoint_test",
    configs = ["//tests/docker/configs:set_cmd_and_entrypoint.yaml"],
    image = ":set_cmd_and_entrypoint",
)

container_image(
    name = "base_with_cmd_and_entrypoint",
    base = ":set_cmd_and_entrypoint",
)

container_test(
    name = "base_with_cmd_and_entrypoint_test",
    configs = ["//tests/docker/configs:set_cmd_and_entrypoint.yaml"],
    image = ":base_with_cmd_and_entrypoint",
)

container_image(
    name = "null_cmd_and_entrypoint_none",
    base = ":set_cmd_and_entrypoint",
    cmd = None,
    entrypoint = None,
)

container_test(
    name = "null_cmd_and_entrypoint_none_test",
    configs = ["//tests/docker/configs:null_cmd_and_entrypoint.yaml"],
    image = ":null_cmd_and_entrypoint_none",
)

container_image(
    name = "null_cmd_and_entrypoint_empty_str",
    base = ":set_cmd_and_entrypoint",
    cmd = "",
    entrypoint = "",
)

container_test(
    name = "null_cmd_and_entrypoint_empty_str_test",
    configs = ["//tests/docker/configs:null_cmd_and_entrypoint.yaml"],
    image = ":null_cmd_and_entrypoint_empty_str",
)

container_image(
    name = "null_cmd_and_entrypoint_empty_list",
    base = ":set_cmd_and_entrypoint",
    cmd = [],
    entrypoint = [],
)

container_test(
    name = "null_cmd_and_entrypoint_empty_list_test",
    configs = ["//tests/docker/configs:null_cmd_and_entrypoint.yaml"],
    image = ":null_cmd_and_entrypoint_empty_list",
)

container_image(
    name = "set_cmd_and_entrypoint_null_on_base",
    base = ":null_cmd_and_entrypoint_none",
    cmd = ["foo"],
    entrypoint = ["bar"],
)

container_test(
    name = "set_cmd_and_entrypoint_null_on_base_test",
    configs = ["//tests/docker/configs:set_cmd_and_entrypoint.yaml"],
    image = ":set_cmd_and_entrypoint_null_on_base",
)

java_image(
    name = "java_partial_entrypoint_image",
    runtime_deps = ["//testdata:java_bin_as_lib"],
)

container_test(
    name = "java_partial_entrypoint_image_test",
    configs = ["//tests/docker/configs:java_partial_entrypoint.yaml"],
    image = ":java_partial_entrypoint_image",
)

java_image(
    name = "java_image",
    main_class = "examples.images.Binary",
    runtime_deps = ["//testdata:java_bin_as_lib"],
)

container_test(
    name = "java_entrypoint_image_test",
    configs = ["//tests/docker/configs:java_entrypoint.yaml"],
    image = ":java_image",
)

container_import(
    name = "import_windows_base_image",
    config = "windowsservercore.1803.config.json",
    layers = [],
    manifest = "windowsservercore.1803.manifest.json",
)

container_image(
    name = "basic_windows_image",
    base = ":import_windows_base_image",
    cmd = ["echo bar"],
    operating_system = "windows",
)

container_test(
    name = "basic_windows_image_test",
    configs = ["//tests/docker/configs:windows_image.yaml"],
    driver = "tar",
    image = ":basic_windows_image",
)

file_test(
    name = "test_digest_output1",
    content = "sha256:fd90e88f1c5dfedf89df4469747ada0a28d7c34196bb2ac879cff6f259f65ba5",
    file = ":deb_image_with_dpkgs.digest",
)

file_test(
    name = "test_digest_output2",
    content = "sha256:5126c97392b596711e00f5af71675581978475cf1490d12a55d4b321ceeee392",
    file = ":null_cmd_and_entrypoint_none.digest",
)
