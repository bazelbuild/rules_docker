load("@io_bazel_rules_docker//java:image.bzl", "java_image")

package(default_visibility = ["//visibility:public"])

java_image(
    name = "java_image",
    srcs = [":Runfiles.java"],
    data = [
        ":foo",
    ],
    main_class = "examples.images.Runfiles",
    deps = [
        "@bazel_tools//tools/java/runfiles",
    ],
)
