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
workspace(name = "io_bazel_rules_docker")

load(
    "//container:container.bzl",
    "container_pull",
    "container_load",
    container_repositories = "repositories",
)

# Consumers shouldn't need to do this themselves once WORKSPACE is
# instantiated recursively.
container_repositories()

# These are for testing.
container_pull(
    name = "distroless_base",
    registry = "gcr.io",
    repository = "distroless/base",
)

container_pull(
    name = "distroless_cc",
    registry = "gcr.io",
    repository = "distroless/cc",
)

container_load(
    name = "pause_tar",
    file = "//testdata:pause.tar",
)

# Have the py_image dependencies for testing.
load(
    "//python:image.bzl",
    _py_image_repos = "repositories",
)

_py_image_repos()

# Have the cc_image dependencies for testing.
load(
    "//cc:image.bzl",
    _cc_image_repos = "repositories",
)

_cc_image_repos()

# Have the java_image dependencies for testing.
load(
    "//java:image.bzl",
    _java_image_repos = "repositories",
)

_java_image_repos()

# For our java_image test.
maven_jar(
    name = "com_google_guava_guava",
    artifact = "com.google.guava:guava:18.0",
    sha1 = "cce0823396aa693798f8882e64213b1772032b09",
)

# For our scala_image test.
git_repository(
    name = "io_bazel_rules_scala",
    commit = "0bac7fe86fdde1cfba3bb2c8a04de5e12de47bcd",
    remote = "https://github.com/bazelbuild/rules_scala.git",
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

# For our groovy_image test.
git_repository(
    name = "io_bazel_rules_groovy",
    commit = "6b8e32ce0f7e33ae1b859706c2dc0c169b966e7e",
    remote = "https://github.com/bazelbuild/rules_groovy.git",
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")

groovy_repositories()

# For our go_image test.
git_repository(
    name = "io_bazel_rules_go",
    commit = "4be196cc186da9dd396d5a45a3a7f343b6abe2b0",
    remote = "https://github.com/bazelbuild/rules_go.git",
)

load("@io_bazel_rules_go//go:def.bzl", "go_repositories")

go_repositories()

# Have the go_image dependencies for testing.
load(
    "//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()

# For our rust_image test
git_repository(
    name = "io_bazel_rules_rust",
    commit = "7b1ba1f2a89006fbe358e97011cb1c1516435806",
    remote = "https://github.com/bazelbuild/rules_rust.git",
)

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

# For our d_image test
git_repository(
    name = "io_bazel_rules_d",
    commit = "0400b9b054013274cee2ed15679da19e1fc94e07",
    remote = "https://github.com/bazelbuild/rules_d.git",
)

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()

# For the container_test rule
git_repository(
    name = "io_bazel_structure_test",
    commit = "fb9284b374f1b987c5a9a1571580853015938d03",
    remote = "https://github.com/GoogleCloudPlatform/container-structure-test.git"
)
