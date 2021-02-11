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
            urls = ["https://github.com/pkg/errors/archive/v0.9.1.tar.gz"],
            sha256 = "56bfd893023daa498508bfe161de1be83299fcf15376035e7df79cbd7d6fa608",
            importpath = "github.com/pkg/errors",
            strip_prefix = "errors-0.9.1",
        )
    if "in_gopkg_yaml_v2" not in excludes:
        go_repository(
            name = "in_gopkg_yaml_v2",
            urls = ["https://github.com/go-yaml/yaml/archive/v2.2.8.tar.gz"],
            sha256 = "9632d0760e9a07c414f2b2b6cd453d6225e42ecea77906883b23f1f1d0546045",
            importpath = "gopkg.in/yaml.v2",
            strip_prefix = "yaml-2.2.8",
        )
    if "com_github_kylelemons_godebug" not in excludes:
        go_repository(
            name = "com_github_kylelemons_godebug",
            urls = ["https://github.com/kylelemons/godebug/archive/v1.1.0.tar.gz"],
            sha256 = "72cc6f274fbd165b7674280f836a6b400e80dbae055919e101920dedf50e79db",
            importpath = "github.com/kylelemons/godebug",
            strip_prefix = "godebug-1.1.0",
        )
    if "com_github_ghodss_yaml" not in excludes:
        go_repository(
            name = "com_github_ghodss_yaml",
            urls = ["https://github.com/ghodss/yaml/archive/v1.0.0.tar.gz"],
            sha256 = "8a76b47cd171944612aae1cfa08bbb971b63fec16794c839252808392097de44",
            importpath = "github.com/ghodss/yaml",
            strip_prefix = "yaml-1.0.0",
        )
