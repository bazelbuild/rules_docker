# Copyright 2016 The Bazel Authors. All rights reserved.
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

# Once recursive workspace is implemented in Bazel, this file should cease
# to exist.
"""
Provides functions to pull all Python external package dependencies of this
repository.
"""

load("@rules_python//python:pip.bzl", "pip_install")

def py_deps():
    """Pull in external Python packages needed by py binaries in this repo.

    Pull in all dependencies needed to build the Py binaries in this
    repository. This function assumes the repositories imported by the macro
    'repositories' in //repositories:repositories.bzl have been imported
    already.
    """
    excludes = native.existing_rules().keys()
    if "io_bazel_rules_docker_pip_deps" not in excludes:
        pip_install(
            name = "io_bazel_rules_docker_pip_deps",
            requirements = "@io_bazel_rules_docker//repositories:requirements-pip.txt",
        )
