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

load("@bazel_tools//tools/python:toolchain.bzl", "py_runtime_pair")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

py_runtime(
    name = "default_container_py2_runtime",
    interpreter_path = "/usr/bin/python",
    python_version = "PY2",
)

py_runtime(
    name = "default_container_py3_runtime",
    interpreter_path = "/usr/bin/python3",
    python_version = "PY3",
)

py_runtime_pair(
    name = "default_container_py_runtime_pair",
    py2_runtime = ":default_container_py2_runtime",
    py3_runtime = ":default_container_py3_runtime",
)

# A toolchain to run python outputs inside a container.
# If you are using --incompatible_use_python_toolchains this toolchain must
# be used to indicate the location of python tools inside the container as
# the auto-detected toolchain relies on using "which", which is not present
# in the default python containers.
# If you are using a custom base for py_image which has python tools in a
# different location, you must register that toolchain prior to the
# registration of this one in @io_bazel_rules_docker//python:image.bzl
toolchain(
    name = "container_py_toolchain",
    exec_compatible_with = [
        "@io_bazel_rules_docker//toolchains:run_in_container",
    ],
    toolchain = ":default_container_py_runtime_pair",
    toolchain_type = "@bazel_tools//tools/python:toolchain_type",
)
