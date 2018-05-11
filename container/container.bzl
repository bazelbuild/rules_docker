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

container = struct(
    image = image,
)

# The release of the github.com/google/containerregistry to consume.
CONTAINERREGISTRY_RELEASE = "v0.0.26"

# The release of the container-structure-test repository to use.
# Updated around 1/22/2018.
STRUCTURE_TEST_COMMIT = "b97925142b1a09309537e648ade11b4af47ff7ad"

def repositories():
    """Download dependencies of container rules."""
    excludes = native.existing_rules().keys()

    if "puller" not in excludes:
        native.http_file(
            name = "puller",
            url = ("https://storage.googleapis.com/containerregistry-releases/" +
                   CONTAINERREGISTRY_RELEASE + "/puller.par"),
            sha256 = "42309ba47bb28d1e1b81ef72789dcca396095e191d4f0e49e2e23c297edd27fb",
            executable = True,
        )

    if "importer" not in excludes:
        native.http_file(
            name = "importer",
            url = ("https://storage.googleapis.com/containerregistry-releases/" +
                   CONTAINERREGISTRY_RELEASE + "/importer.par"),
            sha256 = "0a2490584c96bcf961242364d961859b94926182f20a217754730e7097ea6cde",
            executable = True,
        )

    if "containerregistry" not in excludes:
        native.git_repository(
            name = "containerregistry",
            remote = "https://github.com/google/containerregistry.git",
            tag = CONTAINERREGISTRY_RELEASE,
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
            remote = "https://github.com/google/subpar",
            commit = "7e12cc130eb8f09c8cb02c3585a91a4043753c56",
        )

    if "structure_test" not in excludes:
        native.git_repository(
            name = "structure_test",
            remote = "https://github.com/GoogleCloudPlatform/container-structure-test.git",
            commit = STRUCTURE_TEST_COMMIT,
        )

        # For skylark_library.
    if "bazel_skylib" not in excludes:
        native.git_repository(
            name = "bazel_skylib",
            remote = "https://github.com/bazelbuild/bazel-skylib.git",
            tag = "0.2.0",
        )
