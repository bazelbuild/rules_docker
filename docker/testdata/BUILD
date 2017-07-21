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
package(default_visibility = ["//docker:__subpackages__"])

load(
    "//docker:docker.bzl",
    "docker_build",
    "docker_bundle",
    "docker_import",
    "docker_push",
)

genrule(
    name = "gen",
    outs = ["gen.out"],
    cmd = "echo generated > $@",
)

docker_build(
    name = "dummy_repository",
    files = ["foo"],
    repository = "gcr.io/dummy",
)

docker_build(
    name = "no_data_path_image",
    files = ["//docker/testdata/test:test-data"],
    mode = "0644",
)

docker_build(
    name = "data_path_image",
    data_path = ".",
    files = ["//docker/testdata/test:test-data"],
    mode = "0644",
)

docker_build(
    name = "absolute_data_path_image",
    data_path = "/tools/build_defs",
    files = ["//docker/testdata/test:test-data"],
    mode = "0644",
)

docker_build(
    name = "root_data_path_image",
    data_path = "/",
    files = ["//docker/testdata/test:test-data"],
    mode = "0644",
)

docker_build(
    name = "gen_image",
    files = [":gen"],
    mode = "0644",
)

docker_build(
    name = "files_base",
    files = ["foo"],
    mode = "0644",
)

docker_build(
    name = "files_with_files_base",
    base = ":files_base",
    files = ["bar"],
    mode = "0644",
)

docker_build(
    name = "tar_base",
    tars = ["one.tar"],
)

docker_build(
    name = "tar_with_tar_base",
    base = ":tar_base",
    tars = ["two.tar"],
)

docker_build(
    name = "directory_with_tar_base",
    base = ":tar_base",
    directory = "/foo",
    tars = ["two.tar"],
)

docker_build(
    name = "workdir_with_tar_base",
    base = ":tar_base",
    workdir = "/tmp",
)

docker_build(
    name = "files_with_tar_base",
    base = ":tar_base",
    files = ["bar"],
    mode = "0644",
)

docker_build(
    name = "tar_with_files_base",
    base = ":files_base",
    tars = ["two.tar"],
)

# TODO(mattmoor): Test scalar entrypoint
docker_build(
    name = "base_with_entrypoint",
    entrypoint = ["/bar"],
    files = ["bar"],
    mode = "0644",
    ports = ["8080"],
    tars = ["two.tar"],
)

docker_build(
    name = "dashdash_entrypoint",
    entrypoint = [
        "/bar",
        "--",
    ],
)

# TODO(mattmoor): Test scalar cmd
docker_build(
    name = "derivative_with_shadowed_cmd",
    base = ":base_with_entrypoint",
    cmd = ["shadowed-arg"],
    files = ["foo"],
    mode = "0644",
)

docker_build(
    name = "derivative_with_cmd",
    base = ":derivative_with_shadowed_cmd",
    cmd = [
        "arg1",
        "arg2",
    ],
    ports = ["80/tcp"],
    tars = ["one.tar"],
)

docker_build(
    name = "base_with_volume",
    files = [
        "bar",
        "foo",
    ],
    mode = "0644",
    volumes = ["/logs"],
)

docker_build(
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

# docker_build(
#     name = "generated_tarball",
#     tars = [
#         ":extras",
#     ],
# )

docker_build(
    name = "with_env",
    base = ":base_with_volume",
    env = {
        "foo": "/asdf",
        "bar": "blah blah blah",
    },
)

docker_build(
    name = "with_double_env",
    base = ":with_env",
    env = {
        "baz": "${foo} $bar",
    },
)

docker_build(
    name = "with_label",
    base = ":base_with_volume",
    labels = {
        "com.example.foo": "@blah.json",
        "com.example.bar": "@blah.json",
        "com.example.baz": "qux",
    },
)

docker_build(
    name = "with_double_label",
    base = ":with_label",
    labels = {
        "com.example.qux": "@blah-blah.json",
    },
)

[genrule(
    name = "label-" + n,
    outs = ["%s.json" % n],
    cmd = "echo -n '{\"name\": \"%s\"}' > $@" % n,
) for n in [
    "blah",
    "blah-blah",
]]

docker_build(
    name = "with_user",
    base = ":base_with_volume",
    user = "nobody",
)

docker_build(
    name = "link_with_files_base",
    base = ":files_base",
    symlinks = {
        "/usr/bin/java": "/bar",
    },
)

docker_push(
    name = "push_stamp",
    image = ":link_with_files_base",
    registry = "gcr.io",
    repository = "convoy-adapter/bazel-test",
    stamp = True,
    tag = "{BUILD_USER}",
)

docker_build(
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

docker_bundle(
    name = "bundle_test",
    images = {
        "docker.io/ubuntu:latest": ":base_with_entrypoint",
        "us.gcr.io/google-appengine/base:fresh": ":link_with_files_base",
        "gcr.io/google-containers/pause:2.0": ":with_double_env",
    },
)

docker_bundle(
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

genrule(
    name = "generate_deb",
    outs = ["gen.deb"],
    cmd = "$(location :gen_deb) $@",
    tools = [":gen_deb"],
)

# TODO(mattmoor): re-enable once extras.tar works.
# # Both gen.deb and test-data has a test directory, it should appear
# # only once in the resulting layer.
# docker_build(
#     name = "extras_with_deb",
#     data_path = ".",
#     debs = [":gen.deb"],
#     tars = ["extras.tar"],
# )

load(
    "//docker/contrib:with-tag.bzl",
    docker_build_with_tag = "docker_build",
)

docker_build_with_tag(
    name = "build_with_tag",
    base = ":with_user",
    files = ["foo"],
    tag = "gcr.io/build/with:tag",
)

load(
    "//docker/contrib:push-all.bzl",
    docker_pushall = "docker_push",
)

docker_bundle(
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

load("//docker/contrib:passwd.bzl", "passwd_file")

passwd_file(
    name = "testpasswd",
    gid = 2345,
    home = "/myhomedir",
    info = "myusernameinfo",
    shell = "/myshell",
    uid = 1234,
    username = "foobar",
)

docker_build(
    name = "with_passwd",
    tars = [":testpasswd.passwd.tar"],
)

docker_build(
    name = "base_based_warning",
    base = "@distroless_base//image:image.tar",
)

docker_build(
    name = "cc_based_warning",
    base = "@distroless_cc//image:image.tar",
)

# Tests loading a docker_pull'd base.
docker_build(
    name = "cc_based",
    base = "@distroless_cc//image",
)

PAUSE_CONFIG = "2b58359142b094165abfc9ad9c327c453a3eaa624d0c5ee8f0ed1ab50483603b.json"

genrule(
    name = "pause_config",
    srcs = [":pause.tar"],
    outs = ["pause_config.json"],
    cmd = ("tar xOf $(location :pause.tar) %s " +
           "> $(location :pause_config.json)") % PAUSE_CONFIG,
)

PAUSE_LAYERS = [
    "9285c41a2f85a67c85185be04743004e806fd1e16777f2230166281f4e49cb4c",
    "da7bd81140ca921a067c604a3ba3f54d4e0d51ba5276cd9f32ad6a28e588f470",
]

[genrule(
    name = "extract_%s" % id,
    srcs = [":pause.tar"],
    outs = ["%s.tar.gz" % id],
    cmd = ("tar xOf $(location :pause.tar) %s/layer.tar " +
           "| gzip -n > $(location :%s.tar.gz)") % (id, id),
) for id in PAUSE_LAYERS]

docker_import(
    name = "pause_piecemeal",
    config = ":pause_config.json",
    layers = ["%s.tar.gz" % x for x in PAUSE_LAYERS],
)

load(
    "//docker/contrib/python:image.bzl",
    "py_image",
)

py_library(
    name = "py_image_library",
    srcs = ["py_image_library.py"],
)

py_image(
    name = "py_image",
    srcs = ["py_image.py"],
    layers = [
        ":py_image_library",
    ],
    main = "py_image.py",
)

load(
    "//docker/contrib/cc:image.bzl",
    "cc_image",
)

cc_library(
    name = "cc_image_library",
    srcs = ["cc_image_library.cc"],
    hdrs = ["cc_image_library.h"],
)

cc_image(
    name = "cc_image",
    srcs = ["cc_image.cc"],
    # This creates an empty layer, due to linking.
    layers = [":cc_image_library"],
)
