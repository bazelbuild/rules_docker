load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["createImageConfig.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/create_image_config",
    visibility = ["//visibility:private"],
)

go_binary(
    name = "create_image_config",
    embed = [":go_default_library"],
    visibility = ["//visibility:public"],
)
