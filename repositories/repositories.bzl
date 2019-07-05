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
"""Rules for load all dependencies of rules_docker."""

load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
    "http_file",
)
load(
    "@io_bazel_rules_docker//toolchains/docker:toolchain.bzl",
    _docker_toolchain_configure = "toolchain_configure",
)

# The release of the github.com/google/containerregistry to consume.
CONTAINERREGISTRY_RELEASE = "v0.0.36"

_local_tool_build_template = """
sh_binary(
    name = "{name}",
    srcs = ["bin/{name}"],
    visibility = ["//visibility:public"],
)
"""

def _local_tool(repository_ctx):
    rctx = repository_ctx
    realpath = rctx.which(rctx.name)
    rctx.symlink(realpath, "bin/%s" % rctx.name)
    rctx.file(
        "WORKSPACE",
        'workspace(name = "{}")\n'.format(rctx.name),
    )
    rctx.file(
        "BUILD",
        _local_tool_build_template.format(name = rctx.name),
    )

local_tool = repository_rule(
    local = True,
    implementation = _local_tool,
)

def repositories():
    """Download dependencies of container rules."""
    excludes = native.existing_rules().keys()

    if "go_puller" not in excludes:
        # Go puller binary.
        http_file(
            name = "go_puller",
            executable = True,
            sha256 = "facb3d0c81a1b0a524aebcce3e9d8343c239d75b50124ce72d8b07790a7a2e82",
            urls = [("https://storage.googleapis.com/rules_docker/9e1d2fbd0a19a29383e0c2998d77e4e73c32a432/puller-linux-amd64")],
        )

    if "puller" not in excludes:
        # Python puller binary.
        http_file(
            name = "puller",
            executable = True,
            sha256 = "75ffb6edfee4bfcfbccd7ebee641dd90b4e2f73c773a9cca04cd0ec849576624",
            urls = [("https://storage.googleapis.com/containerregistry-releases/" +
                     CONTAINERREGISTRY_RELEASE + "/puller.par")],
        )

    if "importer" not in excludes:
        http_file(
            name = "importer",
            executable = True,
            sha256 = "4516a7bf62b052693001fd2b649080c4bb5228dcf698f31e77481fcb37b82ab4",
            urls = [("https://storage.googleapis.com/containerregistry-releases/" +
                     CONTAINERREGISTRY_RELEASE + "/importer.par")],
        )

    if "loader" not in excludes:
        http_file(
            name = "loader",
            executable = True,
            sha256 = "30bbb44eae9651a55d07fb9d39f58936fe3d9817780e1887df07d7beb21ef5ad",
            urls = [("https://storage.googleapis.com/rules_docker/a08df0ab2a345cd07359bb69672dcf21867e50e5/loader-linux-amd64")],
        )

    if "containerregistry" not in excludes:
        http_archive(
            name = "containerregistry",
            sha256 = "a8cdf2452323e0fefa4edb01c08b2ec438c9fa3192bc9f408b89287598c12abc",
            strip_prefix = "containerregistry-" + CONTAINERREGISTRY_RELEASE[1:],
            urls = [("https://github.com/google/containerregistry/archive/" +
                     CONTAINERREGISTRY_RELEASE + ".tar.gz")],
        )

    # TODO(mattmoor): Remove all of this (copied from google/containerregistry)
    # once transitive workspace instantiation lands.

    if "io_bazel_rules_go" not in excludes:
        http_archive(
            name = "io_bazel_rules_go",
            sha256 = "f04d2373bcaf8aa09bccb08a98a57e721306c8f6043a2a0ee610fd6853dcde3d",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/0.18.6/rules_go-0.18.6.tar.gz",
                "https://github.com/bazelbuild/rules_go/releases/download/0.18.6/rules_go-0.18.6.tar.gz",
            ],
        )

    if "httplib2" not in excludes:
        # TODO(mattmoor): Is there a clean way to override?
        http_archive(
            name = "httplib2",
            build_file_content = """
py_library(
   name = "httplib2",
   srcs = glob(["**/*.py"]),
   data = ["cacerts.txt"],
   visibility = ["//visibility:public"]
)""",
            sha256 = "2dcbd4f20e826d6405593df8c3d6b6e4e369d57586db3ec9bbba0f0e0cdc0916",
            strip_prefix = "httplib2-0.12.1/python2/httplib2/",
            type = "tar.gz",
            urls = ["https://codeload.github.com/httplib2/httplib2/tar.gz/v0.12.1"],
        )

    # Used by oauth2client
    if "six" not in excludes:
        # TODO(mattmoor): Is there a clean way to override?
        http_archive(
            name = "six",
            build_file_content = """
# Rename six.py to __init__.py
genrule(
    name = "rename",
    srcs = ["six.py"],
    outs = ["__init__.py"],
    cmd = "cat $< >$@",
)
py_library(
   name = "six",
   srcs = [":__init__.py"],
   visibility = ["//visibility:public"],
)""",
            sha256 = "e24052411fc4fbd1f672635537c3fc2330d9481b18c0317695b46259512c91d5",
            strip_prefix = "six-1.9.0/",
            type = "tar.gz",
            urls = ["https://pypi.python.org/packages/source/s/six/six-1.9.0.tar.gz"],
        )

    # Used for authentication in containerregistry
    if "oauth2client" not in excludes:
        # TODO(mattmoor): Is there a clean way to override?
        http_archive(
            name = "oauth2client",
            build_file_content = """
py_library(
   name = "oauth2client",
   srcs = glob(["**/*.py"]),
   visibility = ["//visibility:public"],
   deps = [
     "@httplib2//:httplib2",
     "@six//:six",
   ]
)""",
            sha256 = "7230f52f7f1d4566a3f9c3aeb5ffe2ed80302843ce5605853bee1f08098ede46",
            strip_prefix = "oauth2client-4.0.0/oauth2client/",
            type = "tar.gz",
            urls = ["https://codeload.github.com/google/oauth2client/tar.gz/v4.0.0"],
        )

    # Used for parallel execution in containerregistry
    if "concurrent" not in excludes:
        # TODO(mattmoor): Is there a clean way to override?
        http_archive(
            name = "concurrent",
            build_file_content = """
py_library(
   name = "concurrent",
   srcs = glob(["**/*.py"]),
   visibility = ["//visibility:public"]
)""",
            sha256 = "a7086ddf3c36203da7816f7e903ce43d042831f41a9705bc6b4206c574fcb765",
            strip_prefix = "pythonfutures-3.0.5/concurrent/",
            type = "tar.gz",
            urls = ["https://codeload.github.com/agronholm/pythonfutures/tar.gz/3.0.5"],
        )

    # For packaging python tools.
    if "subpar" not in excludes:
        http_archive(
            name = "subpar",
            sha256 = "34bb4dadd86bbdd3b5736952167e20a1a4c27ff739de11532c4ef77c7c6a68d9",
            # Commit from 2019-03-07.
            strip_prefix = "subpar-35bb9f0092f71ea56b742a520602da9b3638a24f",
            urls = ["https://github.com/google/subpar/archive/35bb9f0092f71ea56b742a520602da9b3638a24f.tar.gz"],
        )

    if "structure_test_linux" not in excludes:
        http_file(
            name = "structure_test_linux",
            executable = True,
            sha256 = "cfdfedd77c04becff0ea16a4b8ebc3b57bf404c56e5408b30d4fbb35853db67c",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.8.0/container-structure-test-linux-amd64"],
        )

    if "structure_test_darwin" not in excludes:
        http_file(
            name = "structure_test_darwin",
            executable = True,
            sha256 = "14e94f75112a8e1b08a2d10f2467d27db0b94232a276ddd1e1512593a7b7cf5a",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.8.0/container-structure-test-darwin-amd64"],
        )

    if "container_diff" not in excludes:
        http_file(
            name = "container_diff",
            executable = True,
            sha256 = "65b10a92ca1eb575037c012c6ab24ae6fe4a913ed86b38048781b17d7cf8021b",
            urls = ["https://storage.googleapis.com/container-diff/v0.15.0/container-diff-linux-amd64"],
        )

    if "base_images_docker" not in excludes:
        http_archive(
            name = "base_images_docker",
            sha256 = "a6862114a02723e6d2cede1b0d3e99840a86d9c8fd3ae09f0fc238d542f60637",
            strip_prefix = "base-images-docker-88c5cd81fb4a801680f42b19e23aea5249e1b851",
            urls = ["https://github.com/GoogleCloudPlatform/base-images-docker/archive/88c5cd81fb4a801680f42b19e23aea5249e1b851.tar.gz"],
        )

    # For bzl_library.
    if "bazel_skylib" not in excludes:
        http_archive(
            name = "bazel_skylib",
            sha256 = "2ea8a5ed2b448baf4a6855d3ce049c4c452a6470b1efd1504fdb7c1c134d220a",
            strip_prefix = "bazel-skylib-0.8.0",
            urls = ["https://github.com/bazelbuild/bazel-skylib/archive/0.8.0.tar.gz"],
        )

    if "gzip" not in excludes:
        local_tool(
            name = "gzip",
        )

    if "bazel_gazelle" not in excludes:
        http_archive(
            name = "bazel_gazelle",
            sha256 = "3c681998538231a2d24d0c07ed5a7658cb72bfb5fd4bf9911157c0e9ac6a2687",
            urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/0.17.0/bazel-gazelle-0.17.0.tar.gz"],
        )

    native.register_toolchains(
        # Register the default docker toolchain that expects the 'docker'
        # executable to be in the PATH
        "@io_bazel_rules_docker//toolchains/docker:default_linux_toolchain",
        "@io_bazel_rules_docker//toolchains/docker:default_windows_toolchain",
        "@io_bazel_rules_docker//toolchains/docker:default_osx_toolchain",
    )

    if "docker_config" not in excludes:
        # Automatically configure the docker toolchain rule to use the default
        # docker binary from the system path
        _docker_toolchain_configure(name = "docker_config")
