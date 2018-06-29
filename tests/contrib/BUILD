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
load("//contrib:compare_ids_test.bzl", "compare_ids_test")
load("//tests/contrib:create_failing_test_for_compare_ids_test.bzl", "create_failing_test_for_compare_ids_test")

sh_test(
    name = "rename_image_test",
    srcs = ["rename_image_test.sh"],
    args = [
        "$(location :renamed_image.tar)",
        "new_image_repo:new_image_tag",
    ],
    data = [
        ":renamed_image.tar",
    ],
)

rename_image(
    name = "renamed_image",
    image = "@distroless_base//image",
    new_repo = "new_image_repo",
    new_tag = "new_image_tag",
)

alias(
    name = "duplicate1",
    actual = "@distroless_cc//image",
)

alias(
    name = "duplicate2",
    actual = "duplicate1",
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

create_failing_test_for_compare_ids_test(
    name = "test_compare_ids_test_diff_ids_fails",
    images = [
        "@distroless_fixed_id//image",
        "@distroless_fixed_id_2//image",
    ],
)

create_failing_test_for_compare_ids_test(
    name = "test_compare_ids_test_wrong_id_fails",
    id = "wrong_id",
    images = ["@distroless_fixed_id//image"],
)

create_failing_test_for_compare_ids_test(
    name = "test_compare_ids_test_one_tar_no_id_fails",
    images = ["@distroless_fixed_id//image"],
    reg_exps = [".*One tar provided\. Need either second tar or an id to compare it to\..*"],
)

create_failing_test_for_compare_ids_test(
    name = "test_compare_ids_test_no_images_with_id_fails",
    id = "some_id",
    images = [],
    reg_exps = [".*No images provided for test.*"],
)

genrule(
    name = "make_invalid_tar",
    outs = ["invalid.tar"],
    cmd = "touch random_file.txt && tar -c random_file.txt > $@",
)

create_failing_test_for_compare_ids_test(
    name = "test_compare_ids_invalid_tar_fails",
    id = "some_id",
    images = ["invalid.tar"],
    reg_exps = [".*Unable to extract manifest\.json, make sure .* is a valid docker image.*"],
)
