load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["ociToLegacy.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/pkg/compat",
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)
