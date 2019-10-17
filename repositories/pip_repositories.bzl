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

load("@pip_deps//:requirements.bzl", "pip_install")

def pip_deps():
    """Pull in external pip packages needed by py binaries in this repo.

    Pull in all pip dependencies needed to build the Py binaries in this
    repository. This function assumes the repositories imported by the macros
    'repositories' in //repositories:repositories.bzl and 'py_deps' in
    //repositories:py_repositories.bzl have been imported
    already.
    """
    pip_install()
