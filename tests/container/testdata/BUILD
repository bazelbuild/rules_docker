load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

package(default_visibility = ["//tests:__subpackages__"])

LONG_NAMES = glob(["files/**"])

pkg_tar(
    name = "expected",
    srcs = LONG_NAMES,
    strip_prefix = ".",
)

filegroup(
    name = "source",
    srcs = LONG_NAMES,
)
