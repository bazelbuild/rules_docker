load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "join_layers_lib",
    srcs = ["join_layers.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/join_layers",
    visibility = ["//visibility:private"],
    deps = [
        "//container/go/pkg/compat",
        "//container/go/pkg/utils",
        "@com_github_google_go_containerregistry//pkg/legacy/tarball",
        "@com_github_google_go_containerregistry//pkg/name",
        "@com_github_google_go_containerregistry//pkg/v1:pkg",
        "@com_github_google_go_containerregistry//pkg/v1/tarball",
        "@com_github_pkg_errors//:errors",
    ],
)

go_binary(
    name = "join_layers",
    embed = [":join_layers_lib"],
    visibility = ["//visibility:public"],
)
