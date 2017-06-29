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

licenses(["notice"])  # Apache 2.0

exports_files(["push-tag.sh.tpl"])

TEST_TARGETS = [
    "base_with_entrypoint",
    "base_with_volume",
    "derivative_with_cmd",
    "derivative_with_shadowed_cmd",
    "derivative_with_volume",
    "directory_with_tar_base",
    "files_base",
    "files_with_files_base",
    "files_with_tar_base",
    "tar_base",
    "tar_with_files_base",
    "tar_with_tar_base",
    # TODO(mattmoor): Re-enable once archive is visible
    # "generated_tarball",
    "with_env",
    "with_double_env",
    "with_label",
    "with_double_label",
    "with_user",
    "workdir_with_tar_base",
    "link_with_files_base",
    "build_with_tag",
    "with_passwd",
]

TEST_DATA = [
    "//docker/testdata:%s.tar" % t
    for t in TEST_TARGETS
] + [
    "//docker/testdata:gen_image.tar",
    "//docker/testdata:data_path_image.tar",
    "//docker/testdata:no_data_path_image.tar",
    "//docker/testdata:absolute_data_path_image.tar",
    "//docker/testdata:root_data_path_image.tar",
    "//docker/testdata:dummy_repository.tar",
    # TODO(mattmoor): Re-enable once archive is visible
    # "//docker/testdata:extras_with_deb.tar",
    "//docker/testdata:bundle_test.tar",
    "//docker/testdata:stamped_bundle_test.tar",
    "//docker/testdata:stamped_bundle_test",
    "//docker/testdata:pause_based.tar",
    "//docker/testdata:dashdash_entrypoint.tar",
    "//docker/testdata:base_based.tar",
    "//docker/testdata:cc_based.tar",
]

sh_test(
    name = "build_test",
    size = "medium",
    srcs = [
        "build_test.sh",
    ],
    data = TEST_DATA + ["testenv.sh"],
)

sh_test(
    name = "build_oci_test",
    size = "medium",
    srcs = [
        "build_oci_test.sh",
    ],
    data = TEST_DATA + ["testenv.sh"],
)

# Used by docker_build and friends

py_binary(
    name = "create_image_config",
    srcs = ["create_image_config.py"],
    visibility = ["//visibility:public"],
    deps = [
        ":utils",
        "@containerregistry//:containerregistry",
    ],
)

py_binary(
    name = "extract_config",
    srcs = ["extract_config.py"],
    visibility = ["//visibility:public"],
    deps = [
        "@containerregistry//:containerregistry",
    ],
)

py_binary(
    name = "join_layers",
    srcs = ["join_layers.py"],
    visibility = ["//visibility:public"],
    deps = [
        ":utils",
        "@containerregistry//:containerregistry",
    ],
)

# TODO(mattmoor): Remove this once Bazel releases the centralized copy.
py_binary(
    name = "sha256",
    srcs = ["sha256.py"],
    visibility = ["//visibility:public"],
)

py_library(
    name = "utils",
    srcs = [
        "__init__.py",
        "utils.py",
    ],
)

filegroup(
    name = "incremental_load_template",
    srcs = ["incremental_load.sh.tpl"],
    visibility = ["//visibility:public"],
)
