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

load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "config.go",
        "image.go",
        "image_index.go",
        "reader.go",
        "write.go",
    ],
    importpath = "github.com/bazelbuild/rules_docker/container/go/pkg/compat",
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/tarball:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/types:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)

go_test(
    name = "go_default_test",
    srcs = [
        "compat_test.go",
        "config_test.go",
        "image_index_test.go",
        "write_test.go",
    ],
    embed = [":go_default_library"],
    deps = [
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/empty:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/mutate:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/random:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/types:go_default_library",
        "@com_github_kylelemons_godebug//pretty:go_default_library",
    ],
)
