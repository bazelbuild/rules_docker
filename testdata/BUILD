# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@build_bazel_rules_nodejs//:index.bzl", "nodejs_binary")
load("@io_bazel_rules_docker_pip_deps//:requirements.bzl", "requirement")
load("@io_bazel_rules_go//go:def.bzl", "go_binary")
load("@npm//@bazel/typescript:index.bzl", "ts_library")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("//cc:image.bzl", "cc_image")
load(
    "//container:container.bzl",
    "container_bundle",
    "container_flatten",
    "container_image",
    "container_layer",
    "container_push",
)
load("//contrib:group.bzl", "group_entry", "group_file")
load("//contrib:passwd.bzl", "passwd_entry", "passwd_file", "passwd_tar")
load(
    "//contrib:push-all.bzl",
    docker_pushall = "docker_push",
    oci_pushall = "oci_push",
)
load(
    "//contrib:with-tag.bzl",
    container_image_with_tag = "container_image",
)
load("//d:image.bzl", "d_image")
load("//docker:docker.bzl", "docker_push")
load("//go:image.bzl", "go_image")
load("//groovy:image.bzl", "groovy_image")
load(
    "//java:image.bzl",
    "java_image",
    "war_image",
)
load("//kotlin:image.bzl", "kt_jvm_image")
load("//nodejs:image.bzl", "nodejs_image")
load("//python:image.bzl", "py_image", "py_layer")
load("//python3:image.bzl", "py3_image")
load("//scala:image.bzl", "scala_image")
load("//testdata:utils.bzl", "generate_deb", "rule_with_symlinks")
load(":stamp_info.bzl", "stamp_info")

package(default_visibility = ["//visibility:public"])

exports_files([
    "Binary.java",
    "bar",
    "cc_image.cc",
    "foo",
    "pause.tar",
    "py3_image.py",
    "py_image.py",
])

exports_files(["BUILD"])

exports_files([
    "Binary.groovy",
    "cc_image_library.cc",
    "cc_image_library.h",
    "Library.groovy",
    "Library.java",
    "Library.scala",
    "Library.kt",
    "main.go",
    "main.rs",
    "nodejs_image.js",
    "py_image_library.py",
    "Runfiles.java",
    "Binary.kt",
])

genrule(
    name = "gen",
    outs = ["gen.out"],
    cmd = "echo generated > $@",
)

container_image(
    name = "dummy_repository",
    files = ["foo"],
    repository = "gcr.io/dummy",
)

container_image(
    name = "no_data_path_image",
    files = ["//testdata/test:test-data"],
    mode = "0o644",
)

container_image(
    name = "data_path_image",
    data_path = ".",
    files = ["//testdata/test:test-data"],
    mode = "0o644",
)

container_image(
    name = "absolute_data_path_image",
    data_path = "/tools/build_defs",
    files = ["//testdata/test:test-data"],
    mode = "0o644",
)

container_image(
    name = "root_data_path_image",
    data_path = "/",
    files = ["//testdata/test:test-data"],
    mode = "0o644",
)

container_image(
    name = "gen_image",
    files = [":gen"],
    mode = "0o644",
)

container_image(
    name = "files_base",
    files = ["foo"],
    mode = "0o644",
)

container_image(
    name = "files_with_files_base",
    base = ":files_base",
    files = ["bar"],
    mode = "0o644",
)

container_image(
    name = "files_in_layer_with_files_base",
    base = ":files_base",
    files = ["bar"],
    layers = [":files_in_layer"],
    mode = "0o644",
)

container_layer(
    name = "files_in_layer",
    files = ["baz"],
    mode = "0o644",
)

container_image(
    name = "tar_base",
    tars = ["one.tar"],
)

container_image(
    name = "tar_with_mtimes_preserved",
    base = ":tar_base",
    enable_mtime_preservation = True,
    tars = ["two.tar"],
)

container_image(
    name = "tar_with_tar_base",
    base = ":tar_base",
    tars = ["two.tar"],
)

container_image(
    name = "tars_in_layer_with_tar_base",
    base = ":tar_base",
    layers = [":tars_in_layer"],
    tars = ["two.tar"],
)

container_layer(
    name = "tars_in_layer",
    directory = "/three",
    tars = ["three.tar"],
)

container_image(
    name = "directory_with_tar_base",
    base = ":tar_base",
    directory = "/foo",
    tars = ["two.tar"],
)

container_image(
    name = "workdir_with_tar_base",
    base = ":tar_base",
    workdir = "/tmp",
)

container_image(
    name = "files_with_tar_base",
    base = ":tar_base",
    files = ["bar"],
    mode = "0o644",
)

container_image(
    name = "tar_with_files_base",
    base = ":files_base",
    tars = ["two.tar"],
)

container_image(
    name = "docker_tarball_base",
    base = "@pause_tar//image",
    files = ["foo"],
    mode = "0o644",
)

container_image(
    name = "layers_with_docker_tarball_base",
    base = "@pause_tar//image",
    files = ["foo"],
    layers = [
        ":files_in_layer",
        ":tars_in_layer",
    ],
    mode = "0o644",
)

# TODO(mattmoor): Test scalar entrypoint
container_image(
    name = "base_with_entrypoint",
    entrypoint = ["/bar"],
    files = ["bar"],
    mode = "0o644",
    ports = ["8080"],
    tars = ["two.tar"],
)

container_image(
    name = "dashdash_entrypoint",
    entrypoint = [
        "/bar",
        "--",
    ],
)

# TODO(mattmoor): Test scalar cmd
container_image(
    name = "derivative_with_shadowed_cmd",
    base = ":base_with_entrypoint",
    cmd = ["shadowed-arg"],
    files = ["foo"],
    mode = "0o644",
)

container_image(
    name = "derivative_with_cmd",
    base = ":derivative_with_shadowed_cmd",
    cmd = [
        "arg1",
        "arg2",
    ],
    ports = ["80/tcp"],
    tars = ["one.tar"],
)

container_image(
    name = "base_with_volume",
    files = [
        "bar",
        "foo",
    ],
    mode = "0o644",
    volumes = ["/logs"],
)

container_image(
    name = "derivative_with_volume",
    base = ":base_with_volume",
    volumes = [
        "/asdf",
        "/blah",
    ],
)

# TODO(mattmoor): Needs a visibility change.
# py_binary(
#     name = "extras_gen",
#     srcs = ["extras_gen.py"],
#     deps = ["//container:build_tar_lib"],
# )

# genrule(
#     name = "extras",
#     outs = ["extras.tar"],
#     cmd = "$(location :extras_gen) $@",
#     tools = [":extras_gen"],
# )

# container_image(
#     name = "generated_tarball",
#     tars = [
#         ":extras",
#     ],
# )

container_image(
    name = "with_unix_epoch_creation_time",
    base = ":base_with_volume",
    creation_time = "1234567890.12",
)

# This is to support bazel < 0.12 BUILD_TIMESTAMPs, which were in milliseconds
# by default.
container_image(
    name = "with_millisecond_unix_epoch_creation_time",
    base = ":base_with_volume",
    creation_time = "1234567890123.45",
)

container_image(
    name = "with_rfc_3339_creation_time",
    base = ":base_with_volume",
    creation_time = "1989-05-03T12:58:12.345Z",
)

container_image(
    name = "with_stamped_creation_time",
    base = ":base_with_volume",
    creation_time = "{BUILD_TIMESTAMP}",
    stamp = "//stamp:always",
)

container_image(
    name = "with_base_stamped_image",
    base = ":with_stamped_creation_time",
    stamp = "//stamp:always",
)

container_image(
    name = "with_default_stamped_creation_time",
    base = ":base_with_volume",
    stamp = "//stamp:always",
)

container_image(
    name = "with_env",
    base = ":base_with_volume",
    env = {
        "bar": "blah blah blah",
        "foo": "/asdf",
    },
)

container_image(
    name = "with_double_env",
    base = ":with_env",
    env = {
        "baz": "$${foo} $$bar",
    },
)

container_image(
    name = "layers_with_env",
    base = ":base_with_volume",
    env = {
        "PATH": "$$PATH:/tmp/b:/tmp/c",
        "x": "y",
    },
    layers = [":env_layer"],
)

container_layer(
    name = "env_layer",
    env = {
        "PATH": "$$PATH:/tmp/a",
        "a": "b",
    },
)

container_image(
    name = "with_label",
    base = ":base_with_volume",
    labels = {
        "com.example.bar": "@blah.json",
        "com.example.baz": "qux",
        "com.example.foo": "@blah.json",
    },
)

container_image(
    name = "with_double_label",
    base = ":with_label",
    labels = {
        "com.example.qux": "@blah-blah.json",
    },
)

container_image(
    name = "with_stamp_label",
    base = ":base_with_volume",
    labels = {
        "BUILDER": "{BUILD_USER}",
    },
    stamp = "//stamp:always",
)

[genrule(
    name = "label-" + n,
    outs = ["%s.json" % n],
    cmd = "echo -n '{\"name\": \"%s\"}' > $@" % n,
) for n in [
    "blah",
    "blah-blah",
]]

container_image(
    name = "with_user",
    base = ":base_with_volume",
    user = "nobody",
)

container_image(
    name = "link_with_files_base",
    base = ":files_base",
    symlinks = {
        "/usr/bin/java": "/bar",
    },
)

container_flatten(
    name = "flat",
    image = ":link_with_files_base",
)

container_image(
    name = "image_with_bar",
    files = [
        ":bar",
    ],
)

container_image(
    name = "image_with_bar_and_baz",
    # Deriving from the base as a tar tests for the case where the base image
    # is specified as a tarball to image reader.
    base = ":image_with_bar.tar",
    files = [
        ":baz",
    ],
)

container_flatten(
    name = "flatten_with_tarball_base",
    image = ":image_with_bar_and_baz",
)

docker_push(
    name = "push_stamp",
    image = ":link_with_files_base",
    registry = "gcr.io",
    repository = "convoy-adapter/bazel-oci-test",
    stamp = "//stamp:always",
    tag = "{BUILD_USER}",
)

container_image(
    name = "pause_based",
    base = ":pause.tar",
    files = ["foo"],
)

# We should get a warning when we build/run this.
docker_push(
    name = "push_inadvertent_legacy_base",
    image = ":with_env.tar",
    registry = "gcr.io",
    repository = "convoy-adapter/bazel-test",
    tag = "with_env",
)

# We should get a warning when we build/run this.
docker_push(
    name = "push_legacy_base",
    image = ":pause_based",
    registry = "gcr.io",
    repository = "convoy-adapter/bazel-test",
    tag = "pause_based",
)

container_bundle(
    name = "bundle_test",
    images = {
        "docker.io/ubuntu:latest": ":base_with_entrypoint",
        "gcr.io/google-containers/pause:2.0": ":with_double_env",
        "us.gcr.io/google-appengine/base:fresh": ":link_with_files_base",
    },
)

container_bundle(
    name = "stamped_bundle_test",
    images = {
        # Pad username so that it is long enough.
        "example.com/aaaaa{BUILD_USER}:stamped": ":with_user",
    },
    stamp = "//stamp:always",
)

# Generate a dummy debian package with a test/ directory
py_binary(
    name = "gen_deb",
    srcs = ["gen_deb.py"],
    python_version = "PY3",
    srcs_version = "PY2AND3",
)

generate_deb(
    name = "extras_deb",
)

# TODO(mattmoor): re-enable once extras.tar works.
# # Both gen.deb and test-data has a test directory, it should appear
# # only once in the resulting layer.
# container_image(
#     name = "extras_with_deb",
#     data_path = ".",
#     debs = [":extras_deb.deb"],
#     tars = ["extras.tar"],
# )

container_image_with_tag(
    name = "build_with_tag",
    base = ":with_user",
    files = ["foo"],
    tag = "gcr.io/build/with:tag",
)

# This bundles up a bunch of images into a single tarball,
# which is pushed as a unit below.
container_bundle(
    name = "bundle_to_push",
    images = {
        "asia.gcr.io/convoy-adapter/bazel-test/{BUILD_USER}:baz": ":with_user",
        "eu.gcr.io/convoy-adapter/bazel-test/{BUILD_USER}:bar": ":with_double_env",
        "us.gcr.io/convoy-adapter/bazel-test/{BUILD_USER}:foo": ":with_env",
    },
)

docker_pushall(
    name = "push_bundle",
    bundle = ":bundle_to_push",
)

oci_pushall(
    name = "push_bundle_oci",
    bundle = ":bundle_to_push",
)

passwd_entry(
    name = "root_user",
    gid = 0,
    home = "/root",
    info = "Root",
    shell = "/rootshell",
    uid = 0,
    username = "root",
)

passwd_entry(
    name = "foobar_user",
    gid = 2345,
    home = "/myhomedir",
    info = "myusernameinfo",
    shell = "/myshell",
    uid = 1234,
    username = "foobar",
)

passwd_entry(
    name = "nobody_user",
    create_home = False,
    gid = 65534,
    home = "/nonexistent",
    info = "nobody with no home",
    shell = "/sbin/nologin",
    uid = 65534,
    username = "nobody",
)

passwd_file(
    name = "passwd",
    entries = [
        ":root_user",
        ":foobar_user",
        ":nobody_user",
    ],
)

pkg_tar(
    name = "passwd_tar",
    srcs = [":passwd"],
    mode = "0o644",
    package_dir = "etc",
)

passwd_tar(
    name = "password",
    entries = [
        ":root_user",
        ":foobar_user",
        ":nobody_user",
    ],
    passwd_file_pkg_dir = "etc",
)

container_image(
    name = "with_passwd",
    tars = [":passwd_tar"],
)

container_image(
    name = "with_passwd_tar",
    tars = [
        ":password",
    ],
)

group_entry(
    name = "root_group",
    gid = 0,
    groupname = "root",
)

group_entry(
    name = "foobar_group",
    gid = 2345,
    groupname = "foobar",
    users = [
        "foo",
        "bar",
        "baz",
    ],
)

group_file(
    name = "group",
    entries = [
        ":root_group",
        ":foobar_group",
    ],
)

pkg_tar(
    name = "group_tar",
    srcs = [":group"],
    mode = "0o644",
    package_dir = "etc",
)

container_image(
    name = "with_group",
    tars = [":group_tar"],
)

container_image(
    name = "with_empty_files",
    empty_files = [
        "file1",
        "file2",
    ],
    mode = "0o777",
)

container_image(
    name = "with_empty_dirs",
    empty_dirs = [
        "etc",
        "foo",
        "bar",
    ],
    mode = "0o777",
)

container_image(
    name = "base_based_warning",
    base = "@distroless_base//image:image.tar",
)

container_image(
    name = "cc_based_warning",
    base = "@distroless_cc//image:image.tar",
)

# Tests loading a docker_pull'd base.
container_image(
    name = "cc_based",
    base = "@distroless_cc//image",
)

py_image(
    name = "py_image",
    srcs = ["py_image.py"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    layers = [
        "//tests/container/python:py_image_library",
    ],
)

rule_with_symlinks(
    name = "data_with_symlinks",
)

py3_image(
    name = "py_image_with_symlinks_in_data",
    srcs = ["py_image.py"],
    data = [
        ":data_with_symlinks",
    ],
    layers = [
        "//tests/container/python:py_image_library",
    ],
    main = "py_image.py",
)

py_library(
    name = "py_image_library_using_six",
    srcs = ["py_image_library_using_six.py"],
    srcs_version = "PY2AND3",
    deps = [requirement("six")],
)

py_library(
    name = "py_image_complex_library",
    srcs = ["py_image_complex_library.py"],
    srcs_version = "PY2AND3",
    deps = [
        ":py_image_library_using_six",
        "//testdata/test:py_image_library_using_addict",
    ],
)

py_layer(
    name = "py_image_complex_filter_by_path",
    filter = "//testdata/test",
    deps = [":py_image_complex_library"],
)

py_layer(
    name = "py_image_complex_filter_by_path_external_deps",
    filter = "@",
    deps = [":py_image_complex_filter_by_path"],
)

py_layer(
    name = "py_image_complex_external_deps",
    filter = "@",
    deps = [":py_image_complex_library"],
)

py3_image(
    name = "py_image_complex",
    srcs = ["py_image_complex.py"],
    layers = [
        ":py_image_complex_filter_by_path_external_deps",  # addict
        ":py_image_complex_external_deps",  # six
        ":py_image_complex_filter_by_path",  # py_image_library_using_addict
        ":py_image_complex_library",  # py_image_complex_library + py_image_library_using_six
    ],
    main = "py_image_complex.py",
)

py3_image(
    name = "py3_image_with_main",
    srcs = ["py3_image.py"],
    layers = [
        "//tests/container/python:py_image_library",
    ],
    main = "py3_image.py",
)

# The following `container_image` and `py3_image` combination shows how to set
# custom `docker_run_flags` in `py3_image`.
container_image(
    name = "py3_image_base_with_custom_run_flags",
    base = "@py3_image_base//image",
    docker_run_flags = "-i --rm --network=host -e ABC=ABC",
)

py3_image(
    name = "py3_image_with_custom_run_flags",
    srcs = ["py3_image.py"],
    base = ":py3_image_base_with_custom_run_flags",
    layers = [
        "//tests/container/python:py_image_library",
    ],
    main = "py3_image.py",
)

cc_binary(
    name = "cc_binary",
    srcs = ["cc_image.cc"],
    deps = ["//tests/container/cc:cc_image_library"],
)

cc_image(
    name = "cc_binary_as_image",
    binary = ":cc_binary",
)

# Test that we can also load image from within another script.
sh_binary(
    name = "cc_image_wrapper",
    srcs = ["cc_image_wrapper.sh"],
    args = ["$(location //tests/container/cc:cc_image)"],
    data = ["//tests/container/cc:cc_image"],
)

java_library(
    name = "java_image_library",
    srcs = ["Library.java"],
    deps = ["@com_google_guava_guava//jar"],
)

java_image(
    name = "java_image",
    srcs = ["Binary.java"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    jvm_flags = [
        "-Dbuild.location=$(location :BUILD)",
    ],
    layers = [":java_image_library"],
    main_class = "examples.images.Binary",
)

java_image(
    name = "java_partial_entrypoint_image",
    srcs = ["Binary.java"],
    layers = [":java_image_library"],
)

java_image(
    name = "java_sandwich_image",
    srcs = ["Binary.java"],
    layers = ["//tests/container/scala:scala_image_library"],
    main_class = "examples.images.Binary",
)

# The following `container_image` and `java_image` combination shows how to set
# custom `docker_run_flags` in `java_image`.
container_image(
    name = "java_image_base_with_custom_run_flags",
    base = "@java_image_base//image",
    docker_run_flags = "-i --rm --network=host -e ABC=ABC",
)

java_image(
    name = "java_image_with_custom_run_flags",
    base = ":java_image_base_with_custom_run_flags",
    main_class = "examples.images.Binary",
    runtime_deps = ["//tests/container/java:java_bin_as_lib"],
)

java_image(
    name = "java_image_arg_echo",
    srcs = ["ArgEcho.java"],
    args = ["arg0"],
    main_class = "examples.images.ArgEcho",
)

war_image(
    name = "war_image",
    srcs = ["Servlet.java"],
    env = {"WAR_IMAGE_TEST_KEY": "war_image_test_value"},
    layers = [
        ":java_image_library",
        "@javax_servlet_api//jar:jar",
    ],
)

# The following `container_image` and `war_image` combination shows how to set
# custom `docker_run_flags` in `war_image`.
container_image(
    name = "war_image_base_with_custom_run_flags",
    base = "@jetty_image_base//image",
    docker_run_flags = "-i --rm --network=host -e ABC=ABC",
)

war_image(
    name = "war_image_with_custom_run_flags",
    srcs = ["Servlet.java"],
    base = ":war_image_base_with_custom_run_flags",
    layers = [
        ":java_image_library",
        "@javax_servlet_api//jar:jar",
    ],
)

scala_image(
    name = "scala_sandwich_image",
    srcs = ["Binary.scala"],
    layers = [":java_image_library"],
    main_class = "examples.images.Binary",
)

# This calls from Groovy -> Scala -> Java :)
groovy_image(
    name = "groovy_scala_image",
    srcs = ["Binary.groovy"],
    layers = ["//tests/container/scala:scala_image_library"],
    main_class = "examples.images.Binary",
)

kt_jvm_image(
    name = "kotlin_image",
    srcs = [
        "Binary.kt",
        "Library.kt",
    ],
    main_class = "examples.images.Binary",
    deps = [],
)

go_binary(
    name = "launcher",
    srcs = ["launcher_main.go"],
    goarch = "amd64",
    goos = "linux",
    pure = "on",
)

container_image(
    name = "launcher_image",
    base = "//tests/container/go:go_image",
    launcher = ":launcher",
    launcher_args = ["-env-append=CUSTOM_MESSAGE=Launched via launcher!"],
    legacy_run_behavior = False,
)

go_image(
    name = "flag_image",
    srcs = ["flag_main.go"],
    goarch = "amd64",
    goos = "linux",
    pure = "on",
)

d_image(
    name = "d_image",
    srcs = ["main.d"],
    args = [
        "arg0",
        "arg1",
    ],
)

generate_deb(
    name = "pkg1",
)

generate_deb(
    name = "pkg2",
)

generate_deb(
    name = "pkg_control_gz",
    metadata_compression_type = "gzip",
)

generate_deb(
    name = "pkg_control_xz",
    metadata_compression_type = "xz",
)

# Make the Bazel stamp file available in tests.
stamp_info(name = "stamp_info_file")

# Auto-generated by Go linter.
go_binary(
    name = "main",
    srcs = ["main.go"],
)

container_image(
    name = "docker_run_flags_use_default",
    legacy_run_behavior = False,
)

container_image(
    name = "docker_run_flags_overrides_default",
    docker_run_flags = "-i --rm --network=host -e ABC=ABC",
    legacy_run_behavior = False,
)

container_image(
    name = "docker_run_flags_inherits_base",
    base = ":docker_run_flags_overrides_default",
    legacy_run_behavior = False,
)

container_image(
    name = "docker_run_flags_overrides_base",
    base = ":docker_run_flags_overrides_default",
    docker_run_flags = "-i --rm --network=host -e ABC=DEF",
    legacy_run_behavior = False,
)

ts_library(
    name = "nodejs_image_lib",
    srcs = ["nodejs_image_lib.ts"],
    tsconfig = ":tsconfig.json",
    deps = [
        "@npm//@types/jsesc",
        "@npm//@types/node",
        "@npm//jsesc",
    ],
)

nodejs_binary(
    name = "nodejs_image_binary",
    data = [
        ":nodejs_image.js",
        ":nodejs_image_lib",
    ],
    entry_point = ":nodejs_image.js",
)

nodejs_image(
    name = "nodejs_image",
    args = [
        "arg0",
        "arg1",
    ],
    binary = ":nodejs_image_binary",
)

container_image(
    name = "compression_gzip_normal",
    compression = "gzip",
    files = [":foo"],
)

container_image(
    name = "compression_gzip_fast",
    compression = "gzip",
    compression_options = ["--fast"],
    files = [":foo"],
)

container_image(
    name = "compressed_experiment",
    experimental_tarball_format = "compressed",
    files = [":foo"],
)

# push_compression* are built but not executed. This is because building a
# `container_push` appears to be the only way to generated the compressed
# tarball.
container_push(
    name = "push_compression_gzip_normal",
    format = "Docker",
    image = ":compression_gzip_normal",
    registry = "localhost:5000",
    repository = "docker/test/{BUILD_USER}",
    tag = "{BUILD_USER}",
    tags = ["manual"],
)

container_push(
    name = "push_compression_gzip_fast",
    format = "Docker",
    image = ":compression_gzip_fast",
    registry = "localhost:5000",
    repository = "docker/test/{BUILD_USER}",
    tag = "{BUILD_USER}",
    tags = ["manual"],
)

bzl_library(
    name = "stamp_info_bzl",
    srcs = ["stamp_info.bzl"],
    visibility = ["//visibility:private"],
)

bzl_library(
    name = "utils_bzl",
    srcs = ["utils.bzl"],
    visibility = ["//visibility:private"],
)
