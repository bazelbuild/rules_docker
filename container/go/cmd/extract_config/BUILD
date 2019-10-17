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
# Build file for extractConfig binary based on go-containerregistry backend.

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["extract_config.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/extract_config",
    visibility = ["//visibility:private"],
    deps = ["@com_github_google_go_containerregistry//pkg/v1/tarball:go_default_library"],
)

go_binary(
    name = "extract_config",
    embed = [":go_default_library"],
    visibility = ["//visibility:public"],
)
