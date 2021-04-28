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
