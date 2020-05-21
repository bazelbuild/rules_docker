load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_test")
load("@io_bazel_rules_docker//container:testdata.bzl", "TEST_DATA")

go_library(
    name = "go_default_library",
    srcs = ["helpers.go"],
    importpath = "github.com/bazelbuild/rules_docker/container/go/pkg/imagetest",
    visibility = ["//visibility:public"],
)

go_test(
    name = "go_default_test",
    srcs = ["image_test.go"],
    data = TEST_DATA,
    embed = [":go_default_library"],
    deps = ["@com_github_google_go_containerregistry//pkg/v1/tarball:go_default_library"],
)
