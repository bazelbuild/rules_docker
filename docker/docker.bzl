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
"""Rules for manipulation Docker images."""

# Alias docker_build and docker_bundle for now, so folks can move to
# referencing this before it becomes the source of truth.
load(":build.bzl", "docker_build", "build")
load(":bundle.bzl", "docker_bundle")

# Expose the docker_flatten rule.
load(":flatten.bzl", "docker_flatten")

# Expose the docker_import rule.
load(":import.bzl", "docker_import")

# Expose the docker_pull repository rule.
load(":pull.bzl", "docker_pull")

# Expose the docker_push rule.
load(":push.bzl", "docker_push")

docker = struct(
    build = build,
)

# The release of the github.com/google/containerregistry to consume.
CONTAINERREGISTRY_RELEASE = "v0.0.17"

def docker_repositories():
  """Download dependencies of docker rules."""
  excludes = native.existing_rules().keys()

  if "puller" not in excludes:
    native.http_file(
      name = "puller",
      url = ("https://storage.googleapis.com/containerregistry-releases/" +
             CONTAINERREGISTRY_RELEASE + "/puller.par"),
      sha256 = "e252b426ef5ebd412a9209712b8f884025bcec5aa26da96c7759abdcb49791fd",
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
      url = "https://codeload.github.com/httplib2/httplib2/tar.gz/v0.10.3",
      sha256 = "d1bee28a68cc665c451c83d315e3afdbeb5391f08971dcc91e060d5ba16986f1",
      strip_prefix = "httplib2-0.10.3/python2/httplib2/",
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
)"""
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
)"""
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
)"""
    )

  # For packaging python tools.
  if "subpar" not in excludes:
    native.git_repository(
      name = "subpar",
      remote = "https://github.com/google/subpar",
      commit = "7e12cc130eb8f09c8cb02c3585a91a4043753c56",
    )
