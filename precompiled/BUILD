load("@io_bazel_rules_go//go:def.bzl", "go_test")
load(":targets.bzl", "targets")

filegroup(
    name = "binaries",
    srcs = glob([
        "**/loader",
        "**/puller",
    ]),
)

go_test(
    name = "update_test",
    srcs = ["update_test.go"],
    data = [
        "//container/go/cmd/puller:puller",
        "//container/go/cmd/loader:loader",
    ] + targets(),
)
