load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")

go_library(
    name = "go_default_library",
    srcs = ["reader.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/pkg/oci",
    visibility = ["//visibility:public"],
    deps = [
        "@com_github_google_go_containerregistry//pkg/v1:go_default_library",
        "@com_github_google_go_containerregistry//pkg/v1/layout:go_default_library",
        "@com_github_pkg_errors//:go_default_library",
    ],
)

go_test(
    name = "go_default_test",
    srcs = ["reader_test.go"],
    embed = [":go_default_library"],
    deps = ["@com_github_bazelbuild_rules_docker//container/go/pkg/oci/:go_default_library"],
)
