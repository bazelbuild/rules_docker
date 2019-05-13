load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["main.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/extract_config",
    visibility = ["//visibility:private"],
    deps = ["@com_github_google_go_containerregistry//pkg/v1/tarball:go_default_library"],
)

go_binary(
    name = "extract_config",
    embed = [":go_default_library"],
    visibility = ["//visibility:public"],
)
