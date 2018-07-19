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
"""Rules for manipulation container images."""

load("//container:bundle.bzl", "container_bundle")
load("//container:flatten.bzl", "container_flatten")
load("//container:image.bzl", "container_image", "image")
load("//container:layer.bzl", "container_layer")
load("//container:import.bzl", "container_import")
load("//container:load.bzl", "container_load")
load("//container:pull.bzl", "container_pull")
load("//container:push.bzl", "container_push")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

container = struct(
    image = image,
)

# The release of the github.com/google/containerregistry to consume.
CONTAINERREGISTRY_RELEASE = "v0.0.28"

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

    if "puller" not in excludes:
        native.http_file(
            name = "puller",
            url = ("https://storage.googleapis.com/containerregistry-releases/" +
                   CONTAINERREGISTRY_RELEASE + "/puller.par"),
            sha256 = "c834a311a1d2ade959c38c262dfead3b180ba022d196c4a96453d4bfa01e83da",
            executable = True,
        )

    if "importer" not in excludes:
        native.http_file(
            name = "importer",
            url = ("https://storage.googleapis.com/containerregistry-releases/" +
                   CONTAINERREGISTRY_RELEASE + "/importer.par"),
            sha256 = "19643df59bb1dc750e97991e7071c601aa2debe94f6ad72e5f23ab8ae77da46f",
            executable = True,
        )

    if "containerregistry" not in excludes:
        native.http_archive(
            name = "containerregistry",
            url = ("https://github.com/google/containerregistry/archive/" +
                   CONTAINERREGISTRY_RELEASE + ".tar.gz"),
            sha256 = "07b9d06e46a9838bef712116bbda7e094ede37be010c1f8c0a3f32f2eeca6384",
            strip_prefix = "containerregistry-" + CONTAINERREGISTRY_RELEASE[1:],
        )

    # TODO(mattmoor): Remove all of this (copied from google/containerregistry)
    # once transitive workspace instantiation lands.

    if "httplib2" not in excludes:
        # TODO(mattmoor): Is there a clean way to override?
        native.new_http_archive(
            name = "httplib2",
            url = "https://codeload.github.com/httplib2/httplib2/tar.gz/v0.11.3",
            sha256 = "d9f568c183d1230f271e9c60bd99f3f2b67637c3478c9068fea29f7cca3d911f",
            strip_prefix = "httplib2-0.11.3/python2/httplib2/",
            type = "tar.gz",
            build_file_content = """
py_library(
   name = "httplib2",
   srcs = glob(["**/*.py"]),
   data = ["cacerts.txt"],
   visibility = ["//visibility:public"]
)""",
        )

    # Used by oauth2client
    if "six" not in excludes:
        # TODO(mattmoor): Is there a clean way to override?
        native.new_http_archive(
            name = "six",
            url = "https://pypi.python.org/packages/source/s/six/six-1.9.0.tar.gz",
            sha256 = "e24052411fc4fbd1f672635537c3fc2330d9481b18c0317695b46259512c91d5",
            strip_prefix = "six-1.9.0/",
            type = "tar.gz",
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
        )

    # Used for authentication in containerregistry
    if "oauth2client" not in excludes:
        # TODO(mattmoor): Is there a clean way to override?
        native.new_http_archive(
            name = "oauth2client",
            url = "https://codeload.github.com/google/oauth2client/tar.gz/v4.0.0",
            sha256 = "7230f52f7f1d4566a3f9c3aeb5ffe2ed80302843ce5605853bee1f08098ede46",
            strip_prefix = "oauth2client-4.0.0/oauth2client/",
            type = "tar.gz",
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
        )

    # Used for parallel execution in containerregistry
    if "concurrent" not in excludes:
        # TODO(mattmoor): Is there a clean way to override?
        native.new_http_archive(
            name = "concurrent",
            url = "https://codeload.github.com/agronholm/pythonfutures/tar.gz/3.0.5",
            sha256 = "a7086ddf3c36203da7816f7e903ce43d042831f41a9705bc6b4206c574fcb765",
            strip_prefix = "pythonfutures-3.0.5/concurrent/",
            type = "tar.gz",
            build_file_content = """
py_library(
   name = "concurrent",
   srcs = glob(["**/*.py"]),
   visibility = ["//visibility:public"]
)""",
        )

    # For packaging python tools.
    if "subpar" not in excludes:
        native.git_repository(
            name = "subpar",
            remote = "https://github.com/google/subpar.git",
            commit = "7e12cc130eb8f09c8cb02c3585a91a4043753c56",
        )

    if "structure_test_linux" not in excludes:
        http_file(
            name = "structure_test_linux",
            executable = True,
            sha256 = "543577685b33f0483bd4df72534ac9f84c17c9315d8afdcc536cce3591bb8f7c",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.4.0/container-structure-test-linux-amd64"],
        )

    if "structure_test_darwin" not in excludes:
        http_file(
            name = "structure_test_darwin",
            executable = True,
            sha256 = "c1bc8664d411c6df23c002b41ab1b9a3d72ae930f194a997468bfae2f54ca751",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.4.0/container-structure-test-darwin-amd64"],
        )

    # For skylark_library.
    if "bazel_skylib" not in excludes:
        native.git_repository(
            name = "bazel_skylib",
            remote = "https://github.com/bazelbuild/bazel-skylib.git",
            tag = "0.2.0",
        )

    if "gzip" not in excludes:
        local_tool(
            name = "gzip",
        )
