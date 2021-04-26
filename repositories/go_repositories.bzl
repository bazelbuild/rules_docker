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
            commit = "efb2d62d93a7705315b841d0544cb5b13565ff2a",
            importpath = "github.com/google/go-containerregistry",
        )
    if "com_github_pkg_errors" not in excludes:
        go_repository(
            name = "com_github_pkg_errors",
            urls = ["https://api.github.com/repos/pkg/errors/tarball/614d223910a179a466c1767a985424175c39b465"],  # v0.9.1
            sha256 = "208d21a7da574026f68a8c9818fa7c6ede1b514ef9e72dc733b496ddcb7792a6",
            importpath = "github.com/pkg/errors",
            strip_prefix = "pkg-errors-614d223",
            type = "tar.gz",
        )

    if "in_gopkg_yaml_v2" not in excludes:
        go_repository(
            name = "in_gopkg_yaml_v2",
            urls = ["https://api.github.com/repos/go-yaml/yaml/tarball/53403b58ad1b561927d19068c655246f2db79d48"],  # v2.2.8
            sha256 = "7c8b9e36fac643f1b4a5fc1dc578fb569fc3a1d611c02c3338f4efa84de729fa",
            importpath = "gopkg.in/yaml.v2",
            strip_prefix = "go-yaml-yaml-53403b5",
            type = "tar.gz",
        )
    if "com_github_kylelemons_godebug" not in excludes:
        go_repository(
            name = "com_github_kylelemons_godebug",
            urls = ["https://api.github.com/repos/kylelemons/godebug/tarball/9ff306d4fbead574800b66369df5b6144732d58e"],  # v1.1.0
            sha256 = "6151c487936ab72cffbf804626228083c9b3abfc908a2bb41b1160e1e5780aaf",
            importpath = "github.com/kylelemons/godebug",
            strip_prefix = "kylelemons-godebug-9ff306d",
            type = "tar.gz",
        )
    if "com_github_ghodss_yaml" not in excludes:
        go_repository(
            name = "com_github_ghodss_yaml",
            urls = ["https://api.github.com/repos/ghodss/yaml/tarball/0ca9ea5df5451ffdf184b4428c902747c2c11cd7"],  # v1.0.0
            sha256 = "d4bd43ce9348fc1b52af3b7de7a8e62a30d5a02d9137319f312cd95380014f6e",
            importpath = "github.com/ghodss/yaml",
            strip_prefix = "ghodss-yaml-0ca9ea5",
            type = "tar.gz",
        )
