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
            importpath = "github.com/google/go-containerregistry",
            sha256 = "0ccc0e58da12913f9e4bf618073ea2083919efc7dfdf4208b262e54e24cf698f",
            strip_prefix = "go-containerregistry-221517453cf931400e6607315045445644122692",
            type = "zip",
            urls = ["https://codeload.github.com/google/go-containerregistry/zip/221517453cf931400e6607315045445644122692"],
        )
    if "com_github_pkg_errors" not in excludes:
        go_repository(
            name = "com_github_pkg_errors",
            importpath = "github.com/pkg/errors",
            sha256 = "f26b4575fb8a4857a5e7bc910e9400b11ac07dacec05eb000d37b4f0d55ae51f",
            strip_prefix = "errors-0.9.1",
            type = "zip",
            urls = ["https://codeload.github.com/pkg/errors/zip/v0.9.1"],
        )

    if "in_gopkg_yaml_v2" not in excludes:
        go_repository(
            name = "in_gopkg_yaml_v2",
            importpath = "gopkg.in/yaml.v2",
            sha256 = "db2e0ffe81ab370c3e3d3fa9ab7aa05042e51d4b7c2e58f63af2edb29debe5fc",
            strip_prefix = "yaml-2.2.4",
            type = "zip",
            urls = ["https://codeload.github.com/go-yaml/yaml/zip/v2.2.4"],
        )
    if "com_github_kylelemons_godebug" not in excludes:
        go_repository(
            name = "com_github_kylelemons_godebug",
            importpath = "github.com/kylelemons/godebug",
            sha256 = "a07edfa7b01c277196479e1ec51b92b416f2935c049f96917632e9c000e146f8",
            strip_prefix = "godebug-1.1.0",
            type = "zip",
            urls = ["https://codeload.github.com/kylelemons/godebug/zip/v1.1.0"],
        )
    if "com_github_ghodss_yaml" not in excludes:
        go_repository(
            name = "com_github_ghodss_yaml",
            importpath = "github.com/ghodss/yaml",
            sha256 = "13b1657c4c2164634e8ed2b7f425ff59a17c1c6b135d70d4adf68195fd3a810d",
            strip_prefix = "yaml-1.0.0",
            type = "zip",
            urls = ["https://codeload.github.com/ghodss/yaml/zip/v1.0.0"],
        )
