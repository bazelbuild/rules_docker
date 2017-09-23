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

filegroup(
    name = "incremental_load_template",
    srcs = ["incremental_load.sh.tpl"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "extract_config",
    srcs = ["extract_config.py"],
    visibility = ["//visibility:public"],
    deps = [
        "@containerregistry//:containerregistry",
    ],
)

py_library(
    name = "utils",
    srcs = [
        "__init__.py",
        "utils.py",
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
    name = "build_tar",
    srcs = ["build_tar.py"],
    srcs_version = "PY2AND3",
    visibility = ["//visibility:public"],
    deps = [
        "@bazel_tools//third_party/py/gflags",
        "@bazel_tools//tools/build_defs/pkg:archive",
    ],
)
