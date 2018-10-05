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
package(default_visibility = ["//visibility:public"])

load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")
load(
    "//container:container.bzl",
    "container_bundle",
    "container_flatten",
    "container_image",
    "container_layer",
)
load("//testdata:utils.bzl", "generate_deb")

exports_files(["pause.tar"])

exports_files(["BUILD"])

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
    mode = "0644",
)

container_image(
    name = "data_path_image",
    data_path = ".",
    files = ["//testdata/test:test-data"],
    mode = "0644",
)

container_image(
    name = "absolute_data_path_image",
    data_path = "/tools/build_defs",
    files = ["//testdata/test:test-data"],
    mode = "0644",
)

container_image(
    name = "root_data_path_image",
    data_path = "/",
    files = ["//testdata/test:test-data"],
    mode = "0644",
)

container_image(
    name = "gen_image",
    files = [":gen"],
    mode = "0644",
)

container_image(
    name = "files_base",
    files = ["foo"],
    mode = "0644",
)

container_image(
    name = "files_with_files_base",
    base = ":files_base",
    files = ["bar"],
    mode = "0644",
)

container_image(
    name = "files_in_layer_with_files_base",
    base = ":files_base",
    files = ["bar"],
    layers = [":files_in_layer"],
    mode = "0644",
)

container_layer(
    name = "files_in_layer",
    files = ["baz"],
    mode = "0644",
)

container_image(
    name = "tar_base",
    tars = ["one.tar"],
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
    mode = "0644",
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
    mode = "0644",
)

container_image(
    name = "layers_with_docker_tarball_base",
    base = "@pause_tar//image",
    files = ["foo"],
    layers = [
        ":files_in_layer",
        ":tars_in_layer",
    ],
    mode = "0644",
)

# TODO(mattmoor): Test scalar entrypoint
container_image(
    name = "base_with_entrypoint",
    entrypoint = ["/bar"],
    files = ["bar"],
    mode = "0644",
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
    mode = "0644",
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
    mode = "0644",
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
#     deps = ["@bazel_tools//tools/build_defs/pkg:archive"],
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
    stamp = True,
)

container_image(
    name = "with_default_stamped_creation_time",
    base = ":base_with_volume",
    stamp = True,
)

container_image(
    name = "with_env",
    base = ":base_with_volume",
    env = {
        "foo": "/asdf",
        "bar": "blah blah blah",
    },
)

container_image(
    name = "with_double_env",
    base = ":with_env",
    env = {
        "baz": "${foo} $bar",
    },
)

container_image(
    name = "layers_with_env",
    base = ":base_with_volume",
    env = {
        "PATH": "$PATH:/tmp/b:/tmp/c",
        "x": "y",
    },
    layers = [":env_layer"],
)

container_layer(
    name = "env_layer",
    env = {
        "PATH": "$PATH:/tmp/a",
        "a": "b",
    },
)

container_image(
    name = "with_label",
    base = ":base_with_volume",
    labels = {
        "com.example.foo": "@blah.json",
        "com.example.bar": "@blah.json",
        "com.example.baz": "qux",
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
    stamp = True,
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

load("//docker:docker.bzl", "docker_push")

docker_push(
    name = "push_stamp",
    image = ":link_with_files_base",
    registry = "gcr.io",
    repository = "convoy-adapter/bazel-oci-test",
    stamp = True,
    tag = "{BUILD_USER}",
)

load("//oci:oci.bzl", "oci_push")

oci_push(
    name = "push_stamp_oci",
    image = ":link_with_files_base",
    registry = "gcr.io",
    repository = "convoy-adapter/bazel-oci-test",
    stamp = True,
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
        "us.gcr.io/google-appengine/base:fresh": ":link_with_files_base",
        "gcr.io/google-containers/pause:2.0": ":with_double_env",
    },
)

container_bundle(
    name = "stamped_bundle_test",
    images = {
        # Pad username so that it is long enough.
        "example.com/aaaaa{BUILD_USER}:stamped": ":with_user",
    },
    stamp = True,
)

# Generate a dummy debian package with a test/ directory
py_binary(
    name = "gen_deb",
    srcs = ["gen_deb.py"],
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

load(
    "//contrib:with-tag.bzl",
    container_image_with_tag = "container_image",
)

container_image_with_tag(
    name = "build_with_tag",
    base = ":with_user",
    files = ["foo"],
    tag = "gcr.io/build/with:tag",
)

load(
    "//contrib:push-all.bzl",
    docker_pushall = "docker_push",
    oci_pushall = "oci_push",
)

# This bundles up a bunch of images into a single tarball,
# which is pushed as a unit below.
container_bundle(
    name = "bundle_to_push",
    images = {
        "us.gcr.io/convoy-adapter/bazel-test/{BUILD_USER}:foo": ":with_env",
        "eu.gcr.io/convoy-adapter/bazel-test/{BUILD_USER}:bar": ":with_double_env",
        "asia.gcr.io/convoy-adapter/bazel-test/{BUILD_USER}:baz": ":with_user",
    },
    stamp = True,
)

docker_pushall(
    name = "push_bundle",
    bundle = ":bundle_to_push",
)

oci_pushall(
    name = "push_bundle_oci",
    bundle = ":bundle_to_push",
)

load("//contrib:passwd.bzl", "passwd_entry", "passwd_file", "passwd_tar")

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

passwd_file(
    name = "passwd",
    entries = [
        ":root_user",
        ":foobar_user",
    ],
)

pkg_tar(
    name = "passwd_tar",
    srcs = [":passwd"],
    mode = "0644",
    package_dir = "etc",
)

passwd_tar(
    name = "password",
    entries = [
        ":root_user",
        ":foobar_user",
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

load("//contrib:group.bzl", "group_entry", "group_file")

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
    mode = "0644",
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

load("//python:image.bzl", "py_image", "py_layer")

py_library(
    name = "py_image_library",
    srcs = ["py_image_library.py"],
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
        ":py_image_library",
    ],
)

py_image(
    name = "py_image_with_main",
    srcs = ["py_image.py"],
    layers = [
        ":py_image_library",
    ],
    main = "py_image.py",
)

load("@pip_deps//:requirements.bzl", "requirement")

py_library(
    name = "py_image_library_using_six",
    srcs = ["py_image_library_using_six.py"],
    deps = [requirement("six")],
)

py_library(
    name = "py_image_complex_library",
    srcs = ["py_image_complex_library.py"],
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

py_image(
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

load("//python3:image.bzl", "py3_image")

py3_image(
    name = "py3_image",
    srcs = ["py3_image.py"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    layers = [
        ":py_image_library",
    ],
)

py3_image(
    name = "py3_image_with_main",
    srcs = ["py3_image.py"],
    layers = [
        ":py_image_library",
    ],
    main = "py3_image.py",
)

# The following `container_image` and `py3_image` combination shows how to set
# custom `docker_run_flags` in `py3_image`.
# Note that `docker_run_flags` is only used when `legacy_run_behavior` is False.
container_image(
    name = "py3_image_base_with_custom_run_flags",
    base = "@py3_image_base//image",
    docker_run_flags = "-i --rm --network=host -e ABC=ABC",
    legacy_run_behavior = False,
)

py3_image(
    name = "py3_image_with_custom_run_flags",
    srcs = ["py3_image.py"],
    base = ":py3_image_base_with_custom_run_flags",
    layers = [
        ":py_image_library",
    ],
    main = "py3_image.py",
)

load("//cc:image.bzl", "cc_image")

cc_library(
    name = "cc_image_library",
    srcs = ["cc_image_library.cc"],
    hdrs = ["cc_image_library.h"],
)

cc_image(
    name = "cc_image",
    srcs = ["cc_image.cc"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    # This creates an empty layer, due to linking.
    layers = [":cc_image_library"],
)

cc_binary(
    name = "cc_binary",
    srcs = ["cc_image.cc"],
    deps = [":cc_image_library"],
)

cc_image(
    name = "cc_binary_as_image",
    binary = ":cc_binary",
)

# Test that we can also load image from within another script.
sh_binary(
    name = "cc_image_wrapper",
    srcs = ["cc_image_wrapper.sh"],
    args = ["$(location :cc_image)"],
    data = [":cc_image"],
)

load(
    "//java:image.bzl",
    "java_image",
    "war_image",
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
        "-XX:MaxPermSize=128M",
        "-Dbuild.location=$(location :BUILD)",
    ],
    layers = [":java_image_library"],
    main_class = "examples.images.Binary",
)

java_image(
    name = "java_sandwich_image",
    srcs = ["Binary.java"],
    layers = [":scala_image_library"],
    main_class = "examples.images.Binary",
)

java_library(
    name = "java_bin_as_lib",
    srcs = ["Binary.java"],
    deps = [":java_image_library"],
)

java_image(
    name = "java_bin_as_lib_image",
    main_class = "examples.images.Binary",
    runtime_deps = [":java_bin_as_lib"],
)

# The following `container_image` and `java_image` combination shows how to set
# custom `docker_run_flags` in `java_image`.
# Note that `docker_run_flags` is only used when `legacy_run_behavior` is False.
container_image(
    name = "java_image_base_with_custom_run_flags",
    base = "@java_image_base//image",
    docker_run_flags = "-i --rm --network=host -e ABC=ABC",
    legacy_run_behavior = False,
)

java_image(
    name = "java_image_with_custom_run_flags",
    base = ":java_image_base_with_custom_run_flags",
    main_class = "examples.images.Binary",
    runtime_deps = [":java_bin_as_lib"],
)

java_image(
    name = "java_runfiles_image",
    srcs = ["Runfiles.java"],
    data = [
        "foo",
    ],
    main_class = "examples.images.Runfiles",
    deps = [
        "@bazel_tools//tools/java/runfiles",
    ],
)

java_library(
    name = "java_runfiles_as_lib",
    srcs = ["Runfiles.java"],
    data = [
        "foo",
    ],
    deps = [
        "@bazel_tools//tools/java/runfiles",
    ],
)

java_image(
    name = "java_runfiles_as_lib_image",
    main_class = "examples.images.Runfiles",
    runtime_deps = [":java_runfiles_as_lib"],
)

war_image(
    name = "war_image",
    srcs = ["Servlet.java"],
    layers = [
        ":java_image_library",
        "@javax_servlet_api//jar:jar",
    ],
)

# The following `container_image` and `war_image` combination shows how to set
# custom `docker_run_flags` in `war_image`.
# Note that `docker_run_flags` is only used when `legacy_run_behavior` is False.
container_image(
    name = "war_image_base_with_custom_run_flags",
    base = "@jetty_image_base//image",
    docker_run_flags = "-i --rm --network=host -e ABC=ABC",
    legacy_run_behavior = False,
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

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_library")
load("//scala:image.bzl", "scala_image")

scala_library(
    name = "scala_image_library",
    srcs = ["Library.scala"],
    deps = ["@com_google_guava_guava//jar"],
)

scala_image(
    name = "scala_image",
    srcs = ["Binary.scala"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    jvm_flags = ["-Dbuild.location=$(location :BUILD)"],
    layers = [":scala_image_library"],
    main_class = "examples.images.Binary",
)

scala_image(
    name = "scala_sandwich_image",
    srcs = ["Binary.scala"],
    layers = [":java_image_library"],
    main_class = "examples.images.Binary",
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_library")
load("//groovy:image.bzl", "groovy_image")

groovy_library(
    name = "groovy_image_library",
    srcs = ["Library.groovy"],
    deps = ["@com_google_guava_guava//jar"],
)

groovy_image(
    name = "groovy_image",
    srcs = ["Binary.groovy"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    jvm_flags = ["-Dbuild.location=$(location :BUILD)"],
    layers = [":groovy_image_library"],
    main_class = "examples.images.Binary",
)

# This calls from Groovy -> Scala -> Java :)
groovy_image(
    name = "groovy_scala_image",
    srcs = ["Binary.groovy"],
    layers = [":scala_image_library"],
    main_class = "examples.images.Binary",
)

load("//go:image.bzl", "go_image")

go_image(
    name = "go_image",
    srcs = ["main.go"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
    importpath = "github.com/bazelbuild/rules_docker/docker/testdata",
    tags = [
        "tag1",
        "tag2",
    ],
)

load("//rust:image.bzl", "rust_image")

rust_image(
    name = "rust_image",
    srcs = ["main.rs"],
    args = [
        "arg0",
        "arg1",
        "$(location :BUILD)",
    ],
    data = [":BUILD"],
)

load("//d:image.bzl", "d_image")

# Re-enable once https://github.com/bazelbuild/rules_d/issues/14 is fixed.
#d_image(
#    name = "d_image",
#    srcs = ["main.d"],
#    args = [
#        "arg0",
#        "arg1",
#    ],
#)

load("//nodejs:image.bzl", "nodejs_image")

nodejs_image(
    name = "nodejs_image",
    args = [
        "arg0",
        "arg1",
    ],
    data = [":nodejs_image.js"],
    entry_point = "io_bazel_rules_docker/testdata/nodejs_image.js",
    node_modules = "@npm_deps//:node_modules",
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
