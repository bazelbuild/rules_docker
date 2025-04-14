load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "flattener_lib",
    srcs = ["flattener.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/flattener",
    visibility = ["//visibility:private"],
    deps = [
        "//container/go/pkg/compat",
        "//container/go/pkg/utils",
        "@com_github_google_go_containerregistry//pkg/v1/mutate",
    ],
)

go_binary(
    name = "flattener",
    embed = [":flattener_lib"],
    visibility = ["//visibility:public"],
)
