load("//container:container.bzl", "container_import")

package(default_visibility = ["//visibility:public"])

# this needs to be in a seperate package because it generates identically named
# artifacts as pause_piecemeal
container_import(
    name = "pause_piecemeal_gz",
    config = "//testdata/import:pause_config.json",
    layers = ["//testdata/import:gz_layers"],
)
