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
# Build file for new puller binary based on go-containerregistry backend.
load("@bazel_gazelle//:def.bzl", "gazelle")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

# gazelle:prefix github.com/bazelbuild/rules_docker
gazelle(name = "gazelle")

go_library(
    name = "go_pusher",
    srcs = ["pusher.go"],
    importpath = "github.com/bazelbuild/rules_docker",
    visibility = ["//visibility:private"],
    deps = [
        "//container/go/pkg/compat:go_default_library",
        "//container/go/pkg/oci:go_default_library",
        "//container/go/pkg/utils:go_default_library",
        "@com_github_google_go_containerregistry//pkg/authn:go_default_library",
        "@com_github_google_go_containerregistry//pkg/name:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/remote:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/remote/transport:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)

go_binary(
    name = "pusher",
    embed = [":go_pusher"],
    visibility = ["//visibility:public"],
)
