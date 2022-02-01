load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

# Build file for sha256 binary.

go_library(
    name = "go_default_library",
    srcs = ["sha256.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/sha256",
    visibility = ["//visibility:private"],
)

go_binary(
    name = "sha256",
    embed = [":go_default_library"],
    visibility = ["//visibility:public"],
)
