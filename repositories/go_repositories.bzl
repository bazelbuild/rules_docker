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
            urls = ["https://codeload.github.com/google/go-containerregistry/zip/e5f4efd48dbff3ab3165a944d6777f8db28f0ccb"],  # v0.1.2
            strip_prefix = "go-containerregistry-e5f4efd48dbff3ab3165a944d6777f8db28f0ccb",
            sha256 = "ba9b5ae737f9b7ae153f20cad6d4a56b94949afec1fcb638bb1e3e7cc0028923",
            importpath = "github.com/google/go-containerregistry",
            type = "zip",
        )
    if "com_github_pkg_errors" not in excludes:
        go_repository(
            name = "com_github_pkg_errors",
            urls = ["https://codeload.github.com/pkg/errors/zip/614d223910a179a466c1767a985424175c39b465"],  # v0.9.1
            sha256 = "49c7041442cc15211ee85175c06ffa6520c298b1826ed96354c69f16b6cfd13b",
            importpath = "github.com/pkg/errors",
            strip_prefix = "errors-614d223910a179a466c1767a985424175c39b465",
            type = "zip",
        )

    if "in_gopkg_yaml_v2" not in excludes:
        go_repository(
            name = "in_gopkg_yaml_v2",
            urls = ["https://codeload.github.com/go-yaml/yaml/zip/53403b58ad1b561927d19068c655246f2db79d48"],  # v2.2.8
            sha256 = "6ba5e7e5a1cffe05e7628b8cb441ee860d75e439e567187330b5f5d8d72c1537",
            importpath = "gopkg.in/yaml.v2",
            strip_prefix = "yaml-53403b58ad1b561927d19068c655246f2db79d48",
            type = "zip",
        )
    if "com_github_kylelemons_godebug" not in excludes:
        go_repository(
            name = "com_github_kylelemons_godebug",
            urls = ["https://codeload.github.com/kylelemons/godebug/zip/9ff306d4fbead574800b66369df5b6144732d58e"],  # v1.1.0
            sha256 = "117fb85c4d3e6bf9fe55ad2379aca71fee8f7157f025733a7fb40835a8729188",
            importpath = "github.com/kylelemons/godebug",
            strip_prefix = "godebug-9ff306d4fbead574800b66369df5b6144732d58e",
            type = "zip",
        )
    if "com_github_ghodss_yaml" not in excludes:
        go_repository(
            name = "com_github_ghodss_yaml",
            urls = ["https://codeload.github.com/ghodss/yaml/zip/0ca9ea5df5451ffdf184b4428c902747c2c11cd7"],  # v1.0.0
            sha256 = "6775fdc9ff61c99b9d9ea03df0af793f41d6ec4a7cdbcd04eae1d9911acdf6f9",
            importpath = "github.com/ghodss/yaml",
            strip_prefix = "yaml-0ca9ea5df5451ffdf184b4428c902747c2c11cd7",
            type = "zip",
        )
