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
# ###
# Build file for new utility package that handles conversions between the new OCI image layout
# and the old intermediate format.

load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "image.go",
        "ociToLegacy.go",
        "path.go",
        "reader.go",
    ],
    importpath = "github.com/bazelbuild/rules_docker/container/go/pkg/compat",
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/partial:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/types:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/validate:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)

# This is a three-layer legacy image layout pulled by container_pull from gcr.io/asci-toolchain-sandbox/small_img@sha256:4817a495758a70edcaa9ed6723cd927f21c44e2061313b03aaf5d5ae2c1bff46. This is a very small image created for testing purposes.
filegroup(
    name = "legacy_test_index1",
    srcs = [
        "//container/go/pkg/compat/testdata/test_index1:000.tar.gz",
        "//container/go/pkg/compat/testdata/test_index1:001.tar.gz",
        "//container/go/pkg/compat/testdata/test_index1:002.tar.gz",
        "//container/go/pkg/compat/testdata/test_index1:config.json",
        "//container/go/pkg/compat/testdata/test_index1:digest",
        "//container/go/pkg/compat/testdata/test_index1:manifest.json",
    ],
    visibility = ["//visibility:public"],
)
