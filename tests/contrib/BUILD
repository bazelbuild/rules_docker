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

load("//container:bundle.bzl", "container_bundle")
load("//contrib:compare_ids_test.bzl", "compare_ids_test")
load("//contrib:push-all.bzl", "docker_push")
load("//contrib:rename_image.bzl", "rename_image")
load("//contrib:repro_test.bzl", "container_repro_test")
load("//contrib:test.bzl", "container_test")
load("//docker/toolchain_container:toolchain_container.bzl", "toolchain_container")
load("//tests/contrib:compare_ids_fail_test.bzl", "compare_ids_fail_test")

sh_test(
    name = "rename_image_test",
    srcs = ["rename_image_test.sh"],
    args = [
        "$(location :renamed_image.tar)",
        "new_image_registry.io/new_image_repo:new_image_tag",
    ],
    data = [
        ":renamed_image.tar",
    ],
)

rename_image(
    name = "renamed_image",
    image = "@distroless_base//image",
    new_repo = "new_image_registry.io/new_image_repo",
    new_tag = "new_image_tag",
)

alias(
    name = "duplicate1",
    actual = "@distroless_fixed_id//image",
)

alias(
    name = "duplicate2",
    actual = "@distroless_fixed_id_copy//image",
)

compare_ids_test(
    name = "test_compare_ids_test",
    images = [
        ":duplicate1",
        ":duplicate2",
    ],
)

compare_ids_test(
    name = "test_id_compare_ids_test",
    id = "d86477c0011ee23ba00c9d2ffce09d15a0a9282e9af1f54309ecbb7b2c6736cc",
    images = ["@distroless_fixed_id//image"],
)

compare_ids_fail_test(
    name = "test_compare_ids_test_diff_ids_fails",
    images = [
        "@distroless_fixed_id//image",
        "@distroless_fixed_id_2//image",
    ],
    reg_exps = [".*Executed .* fail.*"],
    tags = ["manual"],  # buildkite-incompatible
)

compare_ids_fail_test(
    name = "test_compare_ids_test_wrong_id_fails",
    id = "wrong_id",
    images = ["@distroless_fixed_id//image"],
    reg_exps = [".*Executed .* fail.*"],
    tags = ["manual"],  # buildkite-incompatible
)

compare_ids_fail_test(
    name = "test_compare_ids_test_one_tar_no_id_fails",
    images = ["@distroless_fixed_id//image"],
    reg_exps = [".*One tar provided\\. Need either second tar or an id to compare it to\\..*"],
    tags = ["manual"],  # buildkite-incompatible
)

compare_ids_fail_test(
    name = "test_compare_ids_test_no_images_with_id_fails",
    id = "some_id",
    images = [],
    reg_exps = [".*No images provided for test.*"],
    tags = ["manual"],  # buildkite-incompatible
)

genrule(
    name = "make_invalid_tar",
    outs = ["invalid.tar"],
    cmd = "touch random_file.txt && tar -c random_file.txt > $@",
)

compare_ids_fail_test(
    name = "test_compare_ids_test_invalid_tar_fails",
    id = "some_id",
    images = ["invalid.tar"],
    reg_exps = [".*Unable to extract manifest\\.json, make sure .* is a valid docker image.*"],
    tags = ["manual"],  # buildkite-incompatible
)

compare_ids_fail_test(
    name = "test_compare_ids_test_diff_ids_fails_no_regex",
    images = [
        "duplicate1",
        "duplicate2",
        "@distroless_fixed_id_2//image",
    ],
    tags = ["manual"],  # buildkite-incompatible
)

compare_ids_fail_test(
    name = "test_compare_ids_test_invalid_tar_fails_multi_regex",
    images = [
        "duplicate1",
        "invalid.tar",
    ],
    reg_exps = [
        ".*Unable to extract manifest\\.json, make sure .* is a valid docker image.*",
        ".*FAILED.*",
    ],
    tags = ["manual"],  # buildkite-incompatible
)

container_bundle(
    name = "create_empty_bundle",
    images = {},
)

docker_push(
    name = "test_docker_push_empty_bundle",
    bundle = ":create_empty_bundle",
)

container_test(
    name = "test_dockerfile_image_docker",
    configs = ["//tests/contrib/configs:dockerfile_image.yaml"],
    image = "@loaded_dockerfile_image_docker//image",
)

toolchain_container(
    name = "img_with_random_file",
    base = "@official_xenial//image",
    files = [":rand_file"],
)

genrule(
    name = "rand_file",
    outs = ["random.txt"],
    cmd = "echo $$RANDOM > $@",
)

container_repro_test(
    name = "set_cmd_repro_test",
    image = "//tests/container:set_cmd",
    tags = ["manual"],  # buildkite-incompatible
    workspace_file = "//:WORKSPACE",
)

container_repro_test(
    name = "derivative_with_volume_repro_test",
    base = "@bazel_320//image",
    container_diff_args = [
        "history",
        "file",
        "size",
        "rpm",
        "apt",
        "pip",
        "node",
    ],
    image = "//testdata:derivative_with_volume",
    # FIXME(alex.eagle): failing on master due to PyYaml upgrade
    # https://buildkite.com/bazel/rules-docker-docker/builds/5615
    tags = ["manual"],
    workspace_file = "//:WORKSPACE",
)

container_repro_test(
    name = "rbe-test-xenial_repro_test",
    image = "//tests/docker/toolchain_container:rbe-test-xenial-with-pkgs",
    tags = ["manual"],  # buildkite-incompatible
    workspace_file = "//:WORKSPACE",
)

container_repro_test(
    name = "random_file_img_non_repro_test",
    image = ":img_with_random_file",
    tags = ["manual"],  # buildkite-incompatible
    want_reproducibility = False,
    workspace_file = "//:WORKSPACE",
)
