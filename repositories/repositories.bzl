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
CONTAINERREGISTRY_RELEASE = "v0.0.34"

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
        http_file(
            name = "puller",
            executable = True,
            sha256 = "2a3ccb6ef8f99ec0053b56380824a7c100ba00eb0e147d1bda748884113542f1",
            urls = [("https://storage.googleapis.com/containerregistry-releases/" +
                     CONTAINERREGISTRY_RELEASE + "/puller.par")],
        )

    if "importer" not in excludes:
        http_file(
            name = "importer",
            executable = True,
            sha256 = "0eec1a4ffb26623dbb4075e5459fa0ede36548edf872d2691ebbcb3c4ccb8cf3",
            urls = [("https://storage.googleapis.com/containerregistry-releases/" +
                     CONTAINERREGISTRY_RELEASE + "/importer.par")],
        )

    if "containerregistry" not in excludes:
        http_archive(
            name = "containerregistry",
            sha256 = "8182728578f7d7178e7efcef8ce9074988a1a2667f20ecff5cf6234fba284dd3",
            strip_prefix = "containerregistry-" + CONTAINERREGISTRY_RELEASE[1:],
            urls = [("https://github.com/google/containerregistry/archive/" +
                     CONTAINERREGISTRY_RELEASE + ".tar.gz")],
        )

    # TODO(mattmoor): Remove all of this (copied from google/containerregistry)
    # once transitive workspace instantiation lands.

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
            sha256 = "d9f568c183d1230f271e9c60bd99f3f2b67637c3478c9068fea29f7cca3d911f",
            strip_prefix = "httplib2-0.11.3/python2/httplib2/",
            type = "tar.gz",
            urls = ["https://codeload.github.com/httplib2/httplib2/tar.gz/v0.11.3"],
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
            sha256 = "cf3762b10426a1887d37f127b4c1390785ecb969254096eb714cc1db371f78d6",
            strip_prefix = "subpar-a4f9b23bf01bcc7a52d458910af65a90ee991aff",
            urls = ["https://github.com/google/subpar/archive/a4f9b23bf01bcc7a52d458910af65a90ee991aff.tar.gz"],
        )

    if "structure_test_linux" not in excludes:
        http_file(
            name = "structure_test_linux",
            executable = True,
            sha256 = "bc18c7587176b728c3ab2dad702598950d0d5961d2e13589a0ddbd53afe3baed",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.7.0/container-structure-test-linux-amd64"],
        )

    if "structure_test_darwin" not in excludes:
        http_file(
            name = "structure_test_darwin",
            executable = True,
            sha256 = "b4a9b2f1d40f443457a073b13e6395b5d5b92faf6aa95a039d67408d0d321fc1",
            urls = ["https://storage.googleapis.com/container-structure-test/v1.7.0/container-structure-test-darwin-amd64"],
        )

    # For bzl_library.
    if "bazel_skylib" not in excludes:
        http_archive(
            name = "bazel_skylib",
            sha256 = "eb5c57e4c12e68c0c20bc774bfbc60a568e800d025557bc4ea022c6479acc867",
            strip_prefix = "bazel-skylib-0.6.0",
            urls = ["https://github.com/bazelbuild/bazel-skylib/archive/0.6.0.tar.gz"],
        )

    if "gzip" not in excludes:
        local_tool(
            name = "gzip",
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
