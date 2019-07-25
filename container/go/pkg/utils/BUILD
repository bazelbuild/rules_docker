load("@io_bazel_rules_go//go:def.bzl", "go_library")

go_library(
    name = "go_default_library",
    srcs = ["utils.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/pkg/utils",
    visibility = ["//visibility:public"],
    deps = [
        "//container/go/pkg/compat:go_default_library",
        "//container/go/pkg/oci:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/tarball:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)
