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

# TODO: `go_repository_default_config` is only useful for working around
# https://github.com/bazelbuild/rules_docker/issues/1902 and could likely be
# removed after https://github.com/bazelbuild/rules_docker/issues/1787
def go_deps(go_repository_default_config = "@//:WORKSPACE"):
    """Pull in external Go packages needed by Go binaries in this repo.

    Pull in all dependencies needed to build the Go binaries in this
    repository. This function assumes the repositories imported by the macro
    'repositories' in //repositories:repositories.bzl have been imported
    already.

    Args:
        go_repository_default_config (str, optional): A file used to determine the root of the workspace.
    """
    go_rules_dependencies()
    go_register_toolchains()
    gazelle_dependencies(go_repository_default_config = go_repository_default_config)
    excludes = native.existing_rules().keys()
    if "com_github_google_go_containerregistry" not in excludes:
        go_repository(
            name = "com_github_google_go_containerregistry",
            urls = ["https://github.com/google/go-containerregistry/archive/v0.5.1.tar.gz"],
            sha256 = "c3e28d8820056e7cc870dbb5f18b4f7f7cbd4e1b14633a6317cef895fdb35203",
            importpath = "github.com/google/go-containerregistry",
            strip_prefix = "go-containerregistry-0.5.1",
            build_directives = [
                # Silence Go module warnings about unused modules.
                "gazelle:exclude pkg/authn/k8schain",
            ],
        )
    if "com_github_pkg_errors" not in excludes:
        go_repository(
            name = "com_github_pkg_errors",
            importpath = "github.com/pkg/errors",
            sum = "h1:FEBLx1zS214owpjy7qsBeixbURkuhQAwrK5UwLGTwt4=",
            version = "v0.9.1",
        )
    if "in_gopkg_yaml_v2" not in excludes:
        go_repository(
            name = "in_gopkg_yaml_v2",
            importpath = "gopkg.in/yaml.v2",
            sum = "h1:obN1ZagJSUGI0Ek/LBmuj4SNLPfIny3KsKFopxRdj10=",
            version = "v2.2.8",
        )
    if "com_github_kylelemons_godebug" not in excludes:
        go_repository(
            name = "com_github_kylelemons_godebug",
            importpath = "github.com/kylelemons/godebug",
            sum = "h1:RPNrshWIDI6G2gRW9EHilWtl7Z6Sb1BR0xunSBf0SNc=",
            version = "v1.1.0",
        )
    if "com_github_ghodss_yaml" not in excludes:
        go_repository(
            name = "com_github_ghodss_yaml",
            importpath = "github.com/ghodss/yaml",
            sum = "h1:wQHKEahhL6wmXdzwWG11gIVCkOv05bNOh+Rxn0yngAk=",
            version = "v1.0.0",
        )
