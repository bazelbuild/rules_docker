load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["join_layers.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/join_layers",
    visibility = ["//visibility:private"],
    deps = ["//container/go/pkg/utils:go_default_library"],
)

go_binary(
    name = "join_layers",
    embed = [":go_default_library"],
    visibility = ["//visibility:public"],
)
