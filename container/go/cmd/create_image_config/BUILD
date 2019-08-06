load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["createImageConfig.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/cmd/create_image_config",
    visibility = ["//visibility:private"],
    deps = [
        "//container/go/pkg/compat:go_default_library",
        "//container/go/pkg/utils:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
    ],
)

go_binary(
    name = "create_image_config",
    embed = [":go_default_library"],
    visibility = ["//visibility:public"],
)
