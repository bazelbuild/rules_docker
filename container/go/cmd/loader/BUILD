load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["loader.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/loader",
    visibility = ["//visibility:private"],
    deps = [
        "//container/go/pkg/oci:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/tarball:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)

go_binary(
    name = "loader",
    embed = [":go_default_library"],
    visibility = ["//visibility:public"],
)
