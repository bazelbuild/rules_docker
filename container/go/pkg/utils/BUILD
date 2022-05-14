load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = [
        "array_string_flags.go",
        "docker_config.go",
        "image_args.go",
        "remote.go",
    ],
    importpath = "github.com/bazelbuild/rules_docker/container/go/pkg/utils",
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_google_go_containerregistry//pkg/authn:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/remote:go_default_library",
    ],
)
