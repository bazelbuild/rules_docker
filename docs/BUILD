load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")

# Workaround https://github.com/bazelbuild/stardoc/issues/25
write_file(
    name = "gen_header",
    out = "header.vm",
    content = [
        "<!-- Generated with Stardoc, Do Not Edit! -->",
        "",
        "${moduleDocstring}",
    ],
)

stardoc(
    name = "container_doc",
    out = "container.md_",
    header_template = ":header.vm",
    input = "//container:container.docs.bzl",
    deps = ["//container:container.docs"],
)

# If these fail, run `bazel run //docs:update`
diff_test(
    name = "check_container",
    failure_message = "Please run bazel run //docs:update",
    file1 = "container.md",
    file2 = ":container_doc",
)

write_file(
    name = "gen_update",
    out = "gen_update.sh",
    content = [
        "#!/usr/bin/env bash",
        "cd $BUILD_WORKSPACE_DIRECTORY",
        "cp -fv bazel-bin/docs/container.md_ docs/container.md",
    ],
)

sh_binary(
    name = "update",
    srcs = [":gen_update"],
    data = [":container_doc"],
)
