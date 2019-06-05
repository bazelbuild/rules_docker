load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "container_puller",
    srcs = ["puller.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/puller",
    visibility = ["//visibility:private"],
)

go_binary(
    name = "puller",
    embed = [":container_puller"],
    visibility = ["//visibility:public"],
)
