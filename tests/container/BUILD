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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(
    "@bazel_tools//tools/build_rules:test_rules.bzl",
    "file_test",
)
load("@rules_python//python:defs.bzl", "py_test")
load("//container:bundle.bzl", "container_bundle")
load(
    "//container:container.bzl",
    "container_image",
    "container_import",
    "container_push",
)
load("//contrib:push-all.bzl", docker_push_all = "docker_push")
load("//contrib:test.bzl", "container_test")
load(":apple.bzl", "create_banana_directory")
load(":empty_layers.bzl", "empty_layers")
load(":pull_info_validation_test.bzl", "pull_info_validation_test")
load(":transitions.bzl", "templated_file", "transition_test")

package(default_visibility = ["//visibility:public"])

# Build an image with 11 layers to create an end to end test for the scenario
# where the puller can download an image and name the layer files such that
# sorting the layer files by their names produces the same order as the order
# of the layers in the image manifest.
empty_layers(
    name = "empty_layer",
    num_layers = 11,
)

container_image(
    name = "image_with_11_layers",
    layers = [
        ":empty_layer_{}".format(i)
        for i in range(11)
    ],
)

container_test(
    name = "structure_test",
    configs = ["//tests/container/configs:test.yaml"],
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
    workdir = "/test",
)

container_test(
    name = "deb_image_with_dpkgs_test",
    configs = ["//tests/container/configs:deb_image_with_dpkgs.yaml"],
    image = ":deb_image_with_dpkgs",
)

container_image(
    name = "set_cmd",
    base = "@distroless_fixed_id//image",
    cmd = ["foo"],
)

container_test(
    name = "set_cmd_test",
    configs = ["//tests/container/configs:set_cmd.yaml"],
    image = ":set_cmd",
)

container_test(
    name = "set_cmd_test_host",
    configs = ["//tests/container/configs:set_cmd.yaml"],
    driver = "host",
    image = ":set_cmd",
)

container_image(
    name = "set_entrypoint",
    base = "@distroless_fixed_id//image",
    entrypoint = ["bar"],
)

container_test(
    name = "set_entrypoint_test",
    configs = ["//tests/container/configs:set_entrypoint.yaml"],
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
    configs = ["//tests/container/configs:set_cmd_and_entrypoint.yaml"],
    image = ":set_cmd_and_entrypoint",
)

container_image(
    name = "base_with_cmd_and_entrypoint",
    base = ":set_cmd_and_entrypoint",
)

container_test(
    name = "base_with_cmd_and_entrypoint_test",
    configs = ["//tests/container/configs:set_cmd_and_entrypoint.yaml"],
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
    configs = ["//tests/container/configs:null_cmd_and_entrypoint.yaml"],
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
    configs = ["//tests/container/configs:null_cmd_and_entrypoint.yaml"],
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
    configs = ["//tests/container/configs:null_cmd_and_entrypoint.yaml"],
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
    configs = ["//tests/container/configs:set_cmd_and_entrypoint.yaml"],
    image = ":set_cmd_and_entrypoint_null_on_base",
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
    configs = ["//tests/container/configs:windows_image.yaml"],
    driver = "tar",
    image = ":basic_windows_image",
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

container_push(
    name = "push_image_with_11_layers",
    format = "Docker",
    image = ":image_with_11_layers",
    registry = "localhost:5000",
    repository = "tests/container/image_with_11_layers",
    tag = "latest",
)
# END_DO_NOT_IMPORT

# The following targets are not imported.
# Digest outputs are only available and tested on GitHub.
# BEGIN_DO_NOT_IMPORT
file_test(
    name = "test_digest_output1",
    content = "sha256:7d1a06dae0021fb7a0bb789d414ec3799a397141d7299dce5ba287627737eaea",
    file = ":deb_image_with_dpkgs.digest",
)

file_test(
    name = "test_digest_output2",
    content = "sha256:cf3bc4bfee0707fc15ee50b27af6dcb0fe6c0585a6ba89870736ac8f72c702e9",
    file = ":null_cmd_and_entrypoint_none.digest",
)
# END_DO_NOT_IMPORT

container_image(
    name = "set_env_csv",
    base = "@distroless_fixed_id//image",
    cmd = ["foo"],
    env = {
        "NO_PROXY": "127.0.0.1,localhost",
    },
)

container_test(
    name = "set_env_csv_test",
    configs = ["//tests/container/configs:set_env_csv.yaml"],
    image = ":set_env_csv",
)

container_image(
    name = "set_env_equals",
    base = "@distroless_fixed_id//image",
    cmd = ["foo"],
    env = {
        "CUDA_PKG_VERSION": "-10-0=10.0.130-1",
        "JAVA_OPTS": "-Dloader.main=com.sample.app.SampleApp",
    },
)

container_test(
    name = "set_env_equals_test",
    configs = ["//tests/container/configs:set_env_equals.yaml"],
    image = ":set_env_equals",
)

# Image with Bazel Make variables in the env field.
container_image(
    name = "set_env_make_vars",
    base = "@distroless_fixed_id//image",
    env = {
        "$(ENV_KEY)": "$(ENV_VALUE)",
    },
)

# This test checks that Bazel Make variables are expanded in the env field.
container_test(
    name = "set_env_make_vars_test",
    configs = ["//tests/container/configs:set_env_make_vars.yaml"],
    image = ":set_env_make_vars",
)

# The following targets are not imported.
# Targets using special characters are only available and tested on GitHub.
# BEGIN_DO_NOT_IMPORT
genrule(
    name = "special_characters_file",
    outs = ["gen= foo.out"],
    cmd = "echo generated > \"$@\"",
)

container_image(
    name = "special_characters",
    base = "@distroless_fixed_id//image",
    directory = "root= dir",
    empty_dirs = ["/empty= dir"],
    empty_files = ["/empty= file"],
    files = [":special_characters_file"],
    symlinks = {"foo= symlink": "root= dir/gen= foo.out"},
)
# END_DO_NOT_IMPORT

container_test(
    name = "special_characters_test",
    configs = ["//tests/container/configs:special_characters.yaml"],
    driver = "tar",
    image = ":special_characters",
)

container_push(
    name = "push_test",
    format = "Docker",
    image = ":set_cmd",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

genrule(
    name = "push_tag_file",
    srcs = [],
    outs = ["test.tag"],
    cmd = """echo test > $@""",
    output_to_bindir = 1,
)

container_push(
    name = "push_tag_file_test",
    format = "Docker",
    image = ":set_cmd",
    registry = "localhost:5000",
    repository = "docker/test",
    tag_file = ":test.tag",
    tags = ["manual"],
)

container_push(
    name = "push_stamped_test",
    format = "Docker",
    image = ":set_cmd",
    registry = "localhost:5000",
    repository = "docker/test/{BUILD_USER}",
    tag = "{BUILD_USER}",
    tags = ["manual"],
)

container_image(
    name = "alpine_with_custom_attr",
    base = "@alpine_linux_amd64//image",
    cmd = ["Hello World!"],
    entrypoint = ["echo"],
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
    layers = [
        "//testdata:env_layer",
        "//testdata:tars_in_layer",
        "//testdata:files_in_layer",
    ],
)

create_banana_directory(
    name = "banana_directory",
)

container_image(
    name = "stripped_directory_name",
    data_path = "banana",
    files = [":banana_directory"],
)

container_test(
    name = "stripped_directory_name_test",
    configs = ["//tests/container/configs:stripped_directory_name.yaml"],
    image = ":stripped_directory_name",
)

container_bundle(
    name = "three_images_bundle",
    images = {
        "localhost:5000/image0:latest": "//testdata:base_with_entrypoint",
        "localhost:5000/image1:latest": "//testdata:link_with_files_base",
        "localhost:5000/image2:latest": "//testdata:with_double_env",
    },
)

docker_push_all(
    name = "test_docker_push_three_images_bundle",
    bundle = ":three_images_bundle",
)

py_test(
    name = "build_tar_test",
    srcs = ["build_tar_test.py"],
    data = [
        "//tests/container/testdata:expected.tar",
        "//tests/container/testdata:source",
    ],
    python_version = "PY3",
    deps = ["//container:build_tar_lib"],
)

# The following targets are not imported.
# container_push targets are only available and tested on GitHub.
# BEGIN_DO_NOT_IMPORT

container_push(
    name = "new_push_test_skip_unchanged_digest_unchanged_tag_1",
    format = "Docker",
    image = "@alpine_linux_ppc64le//image:image.tar",
    registry = "localhost:5000",
    repository = "docker/test",
    skip_unchanged_digest = True,
    tag = "unchanged_tag1",
)

container_push(
    name = "new_push_test_skip_unchanged_digest_unchanged_tag_2",
    format = "Docker",
    image = "@alpine_linux_ppc64le//image:image.tar",
    registry = "localhost:5000",
    repository = "docker/test",
    skip_unchanged_digest = True,
    tag = "unchanged_tag2",
)

container_push(
    name = "new_push_test_skip_unchanged_digest_changed_tag_1",
    format = "Docker",
    image = "@alpine_linux_ppc64le//image:image.tar",
    registry = "localhost:5000",
    repository = "docker/test",
    skip_unchanged_digest = True,
    tag = "changed_tag1",
)

container_push(
    name = "new_push_test_skip_unchanged_digest_changed_tag_2",
    format = "Docker",
    image = "@alpine_linux_amd64//image:image.tar",
    registry = "localhost:5000",
    repository = "docker/test",
    skip_unchanged_digest = True,
    tag = "changed_tag2",
)

container_push(
    name = "new_push_test_oci",
    format = "OCI",
    image = ":set_cmd_and_entrypoint",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_oci_from_new_puller",
    format = "OCI",
    image = "@alpine_linux_amd64//image",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_legacy_from_container_img",
    format = "Docker",
    image = ":alpine_with_custom_attr",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_legacy_from_container_img_with_auth",
    format = "Docker",
    image = ":set_cmd_and_entrypoint",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_legacy_from_new_puller",
    format = "Docker",
    image = "@alpine_linux_ppc64le//image",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_legacy_from_old_puller",
    format = "Docker",
    image = "@alpine_linux_armv6//image",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_tar",
    format = "Docker",
    image = "@alpine_linux_ppc64le//image:image.tar",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_old_puller_tar",
    format = "Docker",
    image = "@alpine_linux_ppc64le//image:image.tar",
    registry = "localhost:5000",
    repository = "docker/test",
    tag = "test",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_oci_tag_file",
    format = "OCI",
    image = ":alpine_with_custom_attr",
    registry = "localhost:5000",
    repository = "docker/test",
    tag_file = ":test.tag",
    tags = ["manual"],
)

container_push(
    name = "new_push_test_legacy_tag_file",
    format = "Docker",
    image = ":set_cmd",
    registry = "localhost:5000",
    repository = "docker/test",
    tag_file = ":test.tag",
    tags = ["manual"],
)

container_push(
    name = "new_push_stamped_test_legacy",
    format = "Docker",
    image = ":set_cmd",
    registry = "localhost:5000",
    repository = "docker/test/{BUILD_USER}",
    tag = "{BUILD_USER}",
    tags = ["manual"],
)

container_push(
    name = "new_push_stamped_test_oci",
    format = "OCI",
    image = "@alpine_linux_amd64//image",
    registry = "localhost:5000",
    repository = "docker/test/{BUILD_USER}",
    tag = "{BUILD_USER}",
    tags = ["manual"],
)

# END_DO_NOT_IMPORT

# The following targets are not imported.
# Digest outputs are only available and tested on GitHub.
# BEGIN_DO_NOT_IMPORT
file_test(
    name = "test_push_digest_output",
    content = "sha256:ea10d597d15d62e3a33ea378f75b08d9afc332f685495900724b857a8b9d2d8a",
    file = ":push_test.digest",
)

# The following four digest tests for puller should be identical. "image.digest" is symlinked from image/digest.
file_test(
    name = "distroless_fixed_id_digest_test",
    content = "sha256:a26dde6863dd8b0417d7060c990abe85c1d2481541568445e82b46de9452cf0c",
    file = "@distroless_fixed_id//image:digest",
)

file_test(
    name = "distroless_fixed_id_image_digest_test",
    content = "sha256:a26dde6863dd8b0417d7060c990abe85c1d2481541568445e82b46de9452cf0c",
    file = "@distroless_fixed_id//image:image.digest",
)

file_test(
    name = "k8s_pause_arm64_digest_test",
    content = "sha256:f365626a556e58189fc21d099fc64603db0f440bff07f77c740989515c544a39",
    file = "@k8s_pause_arm64//image:digest",
)

file_test(
    name = "alpine_custom_attr_digest_test",
    content = "sha256:63a40621b30af05f51fb2b38c2b5c56f9cc82cc605d556e09cacdbbdc5adec63",
    file = ":new_push_test_legacy_from_container_img.digest",
)

file_test(
    name = "new_alpine_linux_armv6_image_tar_digest_test",
    content = "sha256:8876a15fad80a30d9ec8660a09c0b795513febc64084047e394a5b534a596ecd",
    file = ":new_alpine_linux_armv6_image_tar.digest",
)

# END_DO_NOT_IMPORT

# The following targets are not imported.
# new_container_pull targets are only available and tested on GitHub.
# BEGIN_DO_NOT_IMPORT

# Merely testing for the presence of the pulled image.tar for now.
file_test(
    name = "alpine_linux_armv6_tar_test_image_tar",
    file = "@alpine_linux_armv6_tar//image:image.tar",
    regexp = ".*",
)

# Testing for content of downloaded image artifacts.
file_test(
    name = "new_distroless_base_oci_test_config",
    file = "@alpine_linux_armv6_fixed_id//image:config.json",
    regexp = "{\"architecture\":\"arm\",.*",
)

file_test(
    name = "new_distroless_base_oci_test_0_tar_gz",
    file = "@alpine_linux_armv6_fixed_id//image:000.tar.gz",
    regexp = ".*",
)

# Testing all new_container_pull invocations with container_tests
# We are testing for 3 cases: 1) Presence of OCI image format only
#                             2) Presence of image.tar via container_import target
#                             3) Presence of image.tar via "docker" format option
#
# Three cases for alpine armv6 distro
container_image(
    name = "new_alpine_linux_armv6_image_tar",
    base = "@alpine_linux_armv6_tar//image:image.tar",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_image(
    name = "new_alpine_linux_armv6_image_oci_tar",
    base = "@alpine_linux_armv6_fixed_id//image:image.tar",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_image(
    name = "new_alpine_linux_armv6_image_oci",
    base = "@alpine_linux_armv6_fixed_id//image:image",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_test(
    name = "new_alpine_linux_armv6_image_tar_test",
    configs = ["//tests/container/configs:alpine_arm.yaml"],
    image = ":new_alpine_linux_armv6_image_tar",
)

container_test(
    name = "new_alpine_linux_armv6_image_oci_tar_test",
    configs = ["//tests/container/configs:alpine_arm.yaml"],
    image = ":new_alpine_linux_armv6_image_oci_tar",
)

container_test(
    name = "new_alpine_linux_armv6_image_oci_test",
    configs = ["//tests/container/configs:alpine_arm.yaml"],
    image = ":new_alpine_linux_armv6_image_oci",
)

# Three cases for alpine amd64 distro
container_image(
    name = "alpine_linux_amd64_image_tar",
    base = "@alpine_linux_amd64_tar//image:image.tar",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_image(
    name = "alpine_linux_amd64_image_oci_tar",
    base = "@alpine_linux_amd64//image:image.tar",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_image(
    name = "alpine_linux_amd64_image_oci",
    base = "@alpine_linux_amd64//image:image",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_test(
    name = "alpine_linux_amd64_image_tar_test",
    configs = ["//tests/container/configs:alpine_amd64.yaml"],
    image = ":alpine_linux_amd64_image_tar",
)

container_test(
    name = "alpine_linux_amd64_image_oci_tar_test",
    configs = ["//tests/container/configs:alpine_amd64.yaml"],
    image = ":alpine_linux_amd64_image_oci_tar",
)

container_test(
    name = "alpine_linux_amd64_image_oci_test",
    configs = ["//tests/container/configs:alpine_amd64.yaml"],
    image = ":alpine_linux_amd64_image_oci",
)

# Three cases for alpine ppc64le distro
container_image(
    name = "new_alpine_linux_ppc64le_image_tar",
    base = "@alpine_linux_ppc64le_tar//image:image.tar",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_image(
    name = "new_alpine_linux_ppc64le_image_oci_tar",
    base = "@alpine_linux_ppc64le//image:image.tar",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_image(
    name = "new_alpine_linux_ppc64le_image_oci",
    base = "@alpine_linux_ppc64le//image:image",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

# Build a container image configured to use the Go join_layers.
container_image(
    name = "new_alpine_linux_ppc64le_image_oci_go_join_layers",
    base = "@alpine_linux_ppc64le//image:image",
    files = [
        "//testdata:bar",
        "//testdata:foo",
    ],
)

container_test(
    name = "new_alpine_linux_ppc64le_image_tar_test",
    configs = ["//tests/container/configs:alpine_ppc64le.yaml"],
    image = ":new_alpine_linux_ppc64le_image_tar",
)

container_test(
    name = "new_alpine_linux_ppc64le_image_oci_tar_test",
    configs = ["//tests/container/configs:alpine_ppc64le.yaml"],
    image = ":new_alpine_linux_ppc64le_image_oci_tar",
)

container_test(
    name = "new_alpine_linux_ppc64le_image_oci_test",
    configs = ["//tests/container/configs:alpine_ppc64le.yaml"],
    image = ":new_alpine_linux_ppc64le_image_oci",
)

container_test(
    name = "new_alpine_linux_ppc64le_image_oci_go_join_layers_test",
    configs = ["//tests/container/configs:alpine_ppc64le.yaml"],
    # Using the tar driver to force using the Go join layers implementation.
    driver = "tar",
    image = ":new_alpine_linux_ppc64le_image_oci_go_join_layers",
)

# This test is used to check if an architecture label is set properly when set in container_image
# args are the architecture to be matched and the target
container_image(
    name = "alpine_arch_ppc64le",
    architecture = "ppc64le",
    base = "@alpine_linux_ppc64le//image",
)

sh_test(
    name = "architecture_test",
    srcs = ["architecture_test.sh"],
    args = [
        "ppc64le",
        "alpine_arch_ppc64le",
    ],
    data = [":alpine_arch_ppc64le"],
)
# END_DO_NOT_IMPORT

# The following targets are not imported.
# new_container_load targets are only available and tested on GitHub.
# BEGIN_DO_NOT_IMPORT
file_test(
    name = "pause_tar_test_config",
    file = "@pause_tar//image:config.json",
    regexp = "{\"architecture\":\"amd64\",.*",
)

file_test(
    name = "pause_tar_test_0_tar_gz",
    file = "@pause_tar//image:000.tar.gz",
    regexp = ".*",
)

file_test(
    name = "pause_tar_test_1_tar_gz",
    file = "@pause_tar//image:001.tar.gz",
    regexp = ".*",
)

pull_info_validation_test(
    name = "pull_info_validation_test",
    expected_digest = "sha256:a26dde6863dd8b0417d7060c990abe85c1d2481541568445e82b46de9452cf0c",
    expected_registry = "gcr.io",
    expected_repository = "distroless/base",
    target = "@distroless_base_fixed_id//image",
)

# END_DO_NOT_IMPORT

bzl_library(
    name = "apple_bzl",
    srcs = ["apple.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "empty_layers_bzl",
    srcs = ["empty_layers.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "pull_info_validation_test_bzl",
    srcs = ["pull_info_validation_test.bzl"],
    visibility = ["//visibility:private"],
)

TEST_TARGETS = [
    ":base_with_entrypoint",
    ":base_with_volume",
    ":derivative_with_cmd",
    ":derivative_with_shadowed_cmd",
    ":derivative_with_volume",
    ":directory_with_tar_base",
    ":files_base",
    ":files_with_files_base",
    ":files_in_layer_with_files_base",
    ":files_with_tar_base",
    ":tar_base",
    ":tar_with_mtimes_preserved",
    ":tar_with_files_base",
    ":tar_with_tar_base",
    ":tars_in_layer_with_tar_base",
    ":docker_tarball_base",
    ":layers_with_docker_tarball_base",
    # TODO(mattmoor): Re-enable once archive is visible
    # "generated_tarball",
    ":with_unix_epoch_creation_time",
    ":with_millisecond_unix_epoch_creation_time",
    ":with_rfc_3339_creation_time",
    ":with_stamped_creation_time",
    ":with_default_stamped_creation_time",
    ":with_base_stamped_image",
    ":with_env",
    ":layers_with_env",
    ":with_double_env",
    ":with_label",
    ":with_double_label",
    ":with_stamp_label",
    ":with_user",
    ":workdir_with_tar_base",
    ":link_with_files_base",
    ":build_with_tag",
    ":with_passwd",
    ":with_passwd_tar",
    ":with_group",
    ":with_empty_files",
    ":with_empty_dirs",
    ":gen_image",
    ":data_path_image",
    ":no_data_path_image",
    ":absolute_data_path_image",
    ":root_data_path_image",
    ":dummy_repository",
    # TODO(mattmoor): Re-enable once archive is visible
    # "extras_with_deb",
    ":bundle_test",
    ":stamped_bundle_test",
    ":pause_based",
    ":dashdash_entrypoint",
    ":base_based_warning",
    ":cc_based_warning",
    "/pause_piecemeal:image",
    "/pause_piecemeal_gz:image",
    # Re-enable once https://github.com/bazelbuild/rules_d/issues/14 is fixed.
    # "d_image",
    ":java_image",
    ":py_image",
    ":py_image_with_symlinks_in_data",
    ":py_image_complex",
    ":war_image",
    ":flat",
    ":flatten_with_tarball_base",
    ":nodejs_image",
    ":compressed_experiment",
]

TEST_DATA = [
    "//testdata%s.tar" % t
    for t in TEST_TARGETS
] + [
    "//testdata:push_compression_gzip_fast",
    "//testdata:push_compression_gzip_normal",
    "//testdata:stamped_bundle_test",
    "//testdata:stamp_info_file.txt",
    "//tests/container:basic_windows_image.tar",
]

py_test(
    name = "image_test",
    size = "medium",
    srcs = ["image_test.py"],
    data = TEST_DATA,
    python_version = "PY3",
    srcs_version = "PY3",
    deps = ["@containerregistry"],
)

container_image(
    name = "test_install_pkgs",
    base = "//tests/docker/package_managers:test_install_pkgs.tar",
)

container_image(
    name = "test_install_git_for_reproducibility_1",
    base = "//tests/docker/package_managers:install_git_for_reproducibility_1.tar",
)

# Test a container bundle with several images and install_pkgs.
# This should not tax join_layers unnecessarily.
# Run bazel build @io_bazel_rules_docker//tests/container:container_bundle_with_install_pkgs.tar to test.
# Prior to adding a caching step to compat/reader.go, join_layers.go
# would take substantially longer for this target.
container_bundle(
    name = "container_bundle_with_install_pkgs",
    experimental_tarball_format = "compressed",
    images = {
        "install_pkgs_1:latest": ":test_install_pkgs",
        "install_pkgs_2:latest": ":test_install_git_for_reproducibility_1",
        "localhost:5000/image0:latest": "//testdata:base_with_entrypoint",
        "localhost:5000/image1:latest": "//testdata:link_with_files_base",
        "localhost:5000/image2:latest": "//testdata:with_double_env",
        "localhost:5000/image3:latest": "//testdata:with_label",
        "localhost:5000/image4:latest": "//testdata:with_double_label",
    },
)

genrule(
    name = "got_os",
    outs = ["got_os.txt"],
    cmd = select({
        "@platforms//os:windows": "echo windows > \"$@\"",
        "@platforms//os:linux": "echo linux > \"$@\"",
        "@platforms//os:macos": "echo macos > \"$@\"",
    }),
)

genrule(
    name = "got_arch",
    outs = ["got_arch.txt"],
    cmd = select({
        "@platforms//cpu:arm64": "echo arm64 > \"$@\"",
        "@platforms//cpu:aarch64": "echo arm64 > \"$@\"",
        "@platforms//cpu:x86_64": "echo x86_64 > \"$@\"",
        "@platforms//cpu:arm": "echo arm > \"$@\"",
    }),
)

container_image(
    name = "transitioned_image",
    architecture = "arm64",
    files = [
        ":got_arch",
        ":got_os",
    ],
    operating_system = "windows",
)

templated_file(
    name = "transitions_off",
    out = "transitions_off.yaml",
    substitutions =
        select({
            "@platforms//os:linux": ["%WANT_OS%=linux"],
            "@platforms//os:macos": ["%WANT_OS%=macos"],
        }) + select({
            "@platforms//cpu:arm64": ["%WANT_ARCH%=arm64"],
            "@platforms//cpu:aarch64": ["%WANT_ARCH%=arm64"],
            "@platforms//cpu:x86_64": ["%WANT_ARCH%=x86_64"],
        }),
    template = "//tests/container/configs:transitions_off.yaml.tpl",
)

container_test(
    name = "_transitions_on_test_base",
    configs = ["//tests/container/configs:transitions_on.yaml"],
    driver = "tar",
    image = ":transitioned_image",
    # marked manual, because it will only pass if transitions are enabled
    # enabled or disabled
    tags = ["manual"],
)

transition_test(
    name = "transitions_on_test",
    actual = ":_transitions_on_test_base",
    transitions_enabled = True,
)

container_test(
    name = "_transitions_off_test_base",
    configs = ["transitions_off"],
    driver = "tar",
    image = ":transitioned_image",
    # marked manual, because it will only pass if transitions are disabled
    tags = ["manual"],
)

transition_test(
    name = "transitions_off_test",
    actual = ":_transitions_off_test_base",
    transitions_enabled = False,
)
