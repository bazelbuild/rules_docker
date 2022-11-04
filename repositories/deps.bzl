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
Provides functions to pull all external package dependencies of this
repository.
"""

load(":go_repositories.bzl", "go_deps")
load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

# TODO: `go_repository_default_config` is only useful for working around
# https://github.com/bazelbuild/rules_docker/issues/1902 and could likely be
# removed after https://github.com/bazelbuild/rules_docker/issues/1787
def deps(go_repository_default_config = "@//:WORKSPACE"):
    """Pull in external dependencies needed by rules in this repo.

    Pull in all dependencies needed to run rules in this
    repository. This function assumes the repositories imported by the macro
    'repositories' in //repositories:repositories.bzl have been imported
    already.

    Args:
        go_repository_default_config (str, optional): A file used to determine the root of the workspace.
    """
    go_deps(go_repository_default_config = go_repository_default_config)
    rules_pkg_dependencies()
