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

load("//contrib:test.bzl", "container_test")

container_test(
    name = "structure_test",
    configs = ["//tests/container/configs:test.yaml"],
    image = "//testdata:link_with_files_base",
)

container_test(
    name = "deb_image_with_dpkgs_test",
    configs = ["//tests/container/configs:deb_image_with_dpkgs.yaml"],
    image = "//tests/container:deb_image_with_dpkgs",
)

container_test(
    name = "set_cmd_test",
    configs = ["//tests/container/configs:set_cmd.yaml"],
    image = "//tests/container:set_cmd",
)

container_test(
    name = "set_entrypoint_test",
    configs = ["//tests/container/configs:set_entrypoint.yaml"],
    image = "//tests/container:set_entrypoint",
)

container_test(
    name = "set_cmd_and_entrypoint_test",
    configs = ["//tests/container/configs:set_cmd_and_entrypoint.yaml"],
    image = "//tests/container:set_cmd_and_entrypoint",
)

container_test(
    name = "base_with_cmd_and_entrypoint_test",
    configs = ["//tests/container/configs:set_cmd_and_entrypoint.yaml"],
    image = "//tests/container:base_with_cmd_and_entrypoint",
)

container_test(
    name = "null_cmd_and_entrypoint_none_test",
    configs = ["//tests/container/configs:null_cmd_and_entrypoint.yaml"],
    image = "//tests/container:null_cmd_and_entrypoint_none",
)

container_test(
    name = "null_cmd_and_entrypoint_empty_str_test",
    configs = ["//tests/container/configs:null_cmd_and_entrypoint.yaml"],
    image = "//tests/container:null_cmd_and_entrypoint_empty_str",
)

container_test(
    name = "null_cmd_and_entrypoint_empty_list_test",
    configs = ["//tests/container/configs:null_cmd_and_entrypoint.yaml"],
    image = "//tests/container:null_cmd_and_entrypoint_empty_list",
)

container_test(
    name = "set_cmd_and_entrypoint_null_on_base_test",
    configs = ["//tests/container/configs:set_cmd_and_entrypoint.yaml"],
    image = "//tests/container:set_cmd_and_entrypoint_null_on_base",
)

# The following targets are not imported.
# These images are only available and tested on GitHub.
# BEGIN_DO_NOT_IMPORT
container_test(
    name = "alpine_amd64_image_test",
    configs = ["//tests/container/configs:alpine_amd64.yaml"],
    image = "@alpine_linux_amd64//image",
)

container_test(
    name = "alpine_arm_image_test",
    configs = ["//tests/container/configs:alpine_arm.yaml"],
    image = "@alpine_linux_armv6//image",
)

container_test(
    name = "alpine_ppc64le_image_test",
    configs = ["//tests/container/configs:alpine_ppc64le.yaml"],
    image = "@alpine_linux_ppc64le//image",
)
# END_DO_NOT_IMPORT

container_test(
    name = "set_env_csv_test",
    configs = ["//tests/container/configs:set_env_csv.yaml"],
    image = "//tests/container:set_env_csv",
)

container_test(
    name = "set_env_equals_test",
    configs = ["//tests/container/configs:set_env_equals.yaml"],
    image = "//tests/container:set_env_equals",
)

# This test checks that Bazel Make variables are expanded in the env field.
container_test(
    name = "set_env_make_vars_test",
    configs = ["//tests/container/configs:set_env_make_vars.yaml"],
    image = "//tests/container:set_env_make_vars",
)

container_test(
    name = "stripped_directory_name_test",
    configs = ["//tests/container/configs:stripped_directory_name.yaml"],
    image = "//tests/container:stripped_directory_name",
)

# The following targets are not imported.
# new_container_pull targets are only available and tested on GitHub.
# BEGIN_DO_NOT_IMPORT
container_test(
    name = "new_alpine_linux_armv6_image_tar_test",
    configs = ["//tests/container/configs:alpine_arm.yaml"],
    image = "//tests/container:new_alpine_linux_armv6_image_tar",
)

container_test(
    name = "new_alpine_linux_armv6_image_oci_tar_test",
    configs = ["//tests/container/configs:alpine_arm.yaml"],
    image = "//tests/container:new_alpine_linux_armv6_image_oci_tar",
)

container_test(
    name = "new_alpine_linux_armv6_image_oci_test",
    configs = ["//tests/container/configs:alpine_arm.yaml"],
    image = "//tests/container:new_alpine_linux_armv6_image_oci",
)

container_test(
    name = "alpine_linux_amd64_image_tar_test",
    configs = ["//tests/container/configs:alpine_amd64.yaml"],
    image = "//tests/container:alpine_linux_amd64_image_tar",
)

container_test(
    name = "alpine_linux_amd64_image_oci_tar_test",
    configs = ["//tests/container/configs:alpine_amd64.yaml"],
    image = "//tests/container:alpine_linux_amd64_image_oci_tar",
)

container_test(
    name = "alpine_linux_amd64_image_oci_test",
    configs = ["//tests/container/configs:alpine_amd64.yaml"],
    image = "//tests/container:alpine_linux_amd64_image_oci",
)

container_test(
    name = "new_alpine_linux_ppc64le_image_tar_test",
    configs = ["//tests/container/configs:alpine_ppc64le.yaml"],
    image = "//tests/container:new_alpine_linux_ppc64le_image_tar",
)

container_test(
    name = "new_alpine_linux_ppc64le_image_oci_tar_test",
    configs = ["//tests/container/configs:alpine_ppc64le.yaml"],
    image = "//tests/container:new_alpine_linux_ppc64le_image_oci_tar",
)

container_test(
    name = "new_alpine_linux_ppc64le_image_oci_test",
    configs = ["//tests/container/configs:alpine_ppc64le.yaml"],
    image = "//tests/container:new_alpine_linux_ppc64le_image_oci",
)
# END_DO_NOT_IMPORT
