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

load(
    "@bazel_tools//tools/build_rules:test_rules.bzl",
    "file_test",
)
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

package(default_visibility = ["//visibility:public"])

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
    workdir = "/test",
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

container_test(
    name = "alpine_amd64_image_test",
    configs = ["//tests/docker/configs:alpine_amd64.yaml"],
    image = "@alpine_linux_amd64//image",
)

container_test(
    name = "alpine_arm_image_test",
    configs = ["//tests/docker/configs:alpine_arm.yaml"],
    image = "@alpine_linux_armv6//image",
)

container_test(
    name = "alpine_ppc64le_image_test",
    configs = ["//tests/docker/configs:alpine_ppc64le.yaml"],
    image = "@alpine_linux_ppc64le//image",
)

file_test(
    name = "test_digest_output1",
    content = "sha256:12f16b811707264bb51f96e85a5f08f0d23fe874dd857a4cd39f7a90844a8bdb",
    file = ":deb_image_with_dpkgs.digest",
)

file_test(
    name = "test_digest_output2",
    content = "sha256:5126c97392b596711e00f5af71675581978475cf1490d12a55d4b321ceeee392",
    file = ":null_cmd_and_entrypoint_none.digest",
)

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
    configs = ["//tests/docker/configs:set_env_csv.yaml"],
    image = ":set_env_csv",
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
    configs = ["//tests/docker/configs:set_env_make_vars.yaml"],
    image = ":set_env_make_vars",
)

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

container_test(
    name = "special_characters_test",
    configs = ["//tests/docker/configs:special_characters.yaml"],
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

file_test(
    name = "test_push_digest_output",
    content = "sha256:515b5206d4232e54ac4a0c2b45fb9fbe678ccc4f6c228e59024ac3ef61e08133",
    file = ":push_test.digest",
)

file_test(
    name = "distoless_fixed_id_digest_test",
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
    configs = ["//tests/docker/configs:stripped_directory_name.yaml"],
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

container_test(
    name = "basic_dockerfile_image",
    configs = ["//tests/docker/configs:basic_dockerfile.yaml"],
    driver = "tar",
    image = "@basic_dockerfile//image:dockerfile_image",
)
