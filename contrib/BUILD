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

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

exports_files(["push-all.sh.tpl"])

exports_files(["structure-test.sh.tpl"])

exports_files(["compare_ids_test.py"])

exports_files(["compare_ids_test.bzl"])

exports_files(["extract_image_id.py"])

exports_files(["cmp_images.sh.tpl"])

py_binary(
    name = "extract_image_id",
    srcs = [":extract_image_id.py"],
    legacy_create_init = False,
    python_version = "PY3",
    deps = [":extract_image_id_lib"],
)

py_library(
    name = "extract_image_id_lib",
    srcs = [":extract_image_id.py"],
    srcs_version = "PY2AND3",
)

py_binary(
    name = "extract_last_layer",
    srcs = [":extract_last_layer.py"],
    legacy_create_init = False,
    python_version = "PY3",
)

py_binary(
    name = "compare_ids_test",
    srcs = [":compare_ids_test.py"],
    legacy_create_init = False,
    python_version = "PY3",
    deps = [":extract_image_id_lib"],
)

alias(
    name = "structure_test_executable",
    actual = select({
        "@bazel_tools//src/conditions:darwin": "@structure_test_darwin//file",
        "@bazel_tools//src/conditions:linux_aarch64": "@structure_test_linux_aarch64//file",
        "//conditions:default": "@structure_test_linux//file",
    }),
)

bzl_library(
    name = "push-all_bzl",
    srcs = ["push-all.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "with-tag_bzl",
    srcs = ["with-tag.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "repro_test_bzl",
    srcs = ["repro_test.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "compare_ids_test_bzl",
    srcs = ["compare_ids_test.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "with-defaults_bzl",
    srcs = ["with-defaults.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "test_bzl",
    srcs = ["test.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "rename_image_bzl",
    srcs = ["rename_image.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "group_bzl",
    srcs = ["group.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "dockerfile_build_bzl",
    srcs = ["dockerfile_build.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "passwd_bzl",
    srcs = ["passwd.bzl"],
    visibility = ["//visibility:private"],
)
