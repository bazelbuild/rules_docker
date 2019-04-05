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

# Python2 is a dependency of rules_docker due to its dependency on
# containerregistry. To run builds on environments in which 'which python'
# points to python3, you can use the py_runtime target below.
# To use this target, simply add the following flag to your build commands:
# --python_top=//python:py_runtime_2
# Note you need to have a symlink to a valid python2 version in
# '/usr/bin/python2' for this to work.
py_runtime(
    name = "py_runtime_2",
    files = [],
    interpreter_path = "/usr/bin/python2",
)

# Starting with Bazel 0.25.0 we must pass a py_runtime that points
# to valid python2 and python3 tools.
py_runtime(
    name = "default_py_runtime",
    interpreter_path = select({
        # Update paths as appropriate for your system.
        "@bazel_tools//tools/python:PY2": "/usr/bin/python2",
        "@bazel_tools//tools/python:PY3": "/usr/bin/python3",
    }),
    files = [],
)
