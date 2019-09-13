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
Provides functions to pull all Go external package dependencies of this
repository.
"""

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

def go_deps():
    """Pull in external Go packages needed by Go binaries in this repo.

    Pull in all dependencies needed to build the Go binaries in this
    repository. This function assumes the repositories imported by the macro
    'repositories' in //repositories:repositories.bzl have been imported
    already.
    """
    go_rules_dependencies()
    go_register_toolchains()
    gazelle_dependencies()
    excludes = native.existing_rules().keys()
    if "com_github_google_go_containerregistry" not in excludes:
        go_repository(
            name = "com_github_google_go_containerregistry",
            commit = "a8228cdaedffd366395d5a0b3022cd2142fddadb",
            importpath = "github.com/google/go-containerregistry",
        )
    if "com_github_pkg_errors" not in excludes:
        go_repository(
            name = "com_github_pkg_errors",
            commit = "27936f6d90f9c8e1145f11ed52ffffbfdb9e0af7",
            importpath = "github.com/pkg/errors",
        )

    if "in_gopkg_yaml_v2" not in excludes:
        go_repository(
            name = "in_gopkg_yaml_v2",
            commit = "51d6538a90f86fe93ac480b35f37b2be17fef232",  # v2.2.2
            importpath = "gopkg.in/yaml.v2",
        )
