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
# Build for the new writer function to write OCI Format Images to disk.
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = [
        "image.go",
        "reader.go",
        "write.go",
    ],
    importpath = "github.com/bazelbuild/rules_docker/container/go/pkg/oci",
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/empty:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/layout:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/types:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/validate:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)

go_test(
    name = "go_default_test",
    srcs = [
        "reader_test.go",
        "write_test.go",
    ],
    data = glob(["testdata/**"]),
    embed = [":go_default_library"],
    deps = [
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/layout:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/tarball:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/types:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/validate:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)
