package(default_visibility = ["//visibility:public"])

load("@io_bazel_rules_docker//container:import.bzl", "container_import")

container_import(
    name = "image",
    config = "config.json",
    layers = glob(["*.tar.gz"]),
)

exports_files(glob(["**"]))
