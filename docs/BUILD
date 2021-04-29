load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@build_bazel_rules_nodejs//:index.bzl", "generated_file_test")
load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")

# Workaround https://github.com/bazelbuild/stardoc/issues/25
write_file(
    name = "gen_header",
    out = "header.vm",
    content = ["${moduleDocstring}"],
)

stardoc(
    name = "image_doc",
    out = "image.md_",
    header_template = ":header.vm",
    input = "//container:image.bzl",
    deps = ["//container:image"],
)

generated_file_test(
    name = "copy_image",
    src = "image.md",
    generated = ":image.md_",
)

stardoc(
    name = "layer_doc",
    out = "layer.md_",
    header_template = ":header.vm",
    input = "//container:layer.bzl",
    deps = [
        "//container:layer",
        "@bazel_skylib//lib:dicts",
    ],
)

generated_file_test(
    name = "copy_layer",
    src = "layer.md",
    generated = ":layer.md_",
)

stardoc(
    name = "bundle_doc",
    out = "bundle.md_",
    header_template = ":header.vm",
    input = "//container:bundle.bzl",
    deps = [
        "//container:bundle",
    ],
)

generated_file_test(
    name = "copy_bundle",
    src = "bundle.md",
    generated = ":bundle.md_",
)

stardoc(
    name = "import_doc",
    out = "import.md_",
    header_template = ":header.vm",
    input = "//container:import.bzl",
    deps = [
        "//container:import",
        "@bazel_skylib//lib:dicts",
    ],
)

generated_file_test(
    name = "copy_import",
    src = "import.md",
    generated = ":import.md_",
)

stardoc(
    name = "load_doc",
    out = "load.md_",
    header_template = ":header.vm",
    input = "//container:load.bzl",
    deps = [
        "//container:load",
    ],
)

generated_file_test(
    name = "copy_load",
    src = "load.md",
    generated = ":load.md_",
)

stardoc(
    name = "pull_doc",
    out = "pull.md_",
    header_template = ":header.vm",
    input = "//container:pull.bzl",
    deps = [
        "//container:pull",
    ],
)

generated_file_test(
    name = "copy_pull",
    src = "pull.md",
    generated = ":pull.md_",
)

stardoc(
    name = "push_doc",
    out = "push.md_",
    header_template = ":header.vm",
    input = "//container:push.bzl",
    deps = [
        "//container:push",
        "@bazel_skylib//lib:dicts",
    ],
)

generated_file_test(
    name = "copy_push",
    src = "push.md",
    generated = ":push.md_",
)
