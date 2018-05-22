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
    "container_load",
    "container_pull",
    container_repositories = "repositories",
)
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

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

load(
    "//python3:image.bzl",
    _py3_image_repos = "repositories",
)

_py3_image_repos()

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
http_archive(
    name = "io_bazel_rules_scala",
    sha256 = "f5f35de94d2d64e48fb4aef87cf89248b8980cb25f9ff1449575af8d904f41be",
    strip_prefix = "rules_scala-0bac7fe86fdde1cfba3bb2c8a04de5e12de47bcd",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/0bac7fe86fdde1cfba3bb2c8a04de5e12de47bcd.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

# For our groovy_image test.
http_archive(
    name = "io_bazel_rules_groovy",
    sha256 = "c54168848cf2b733cb95fda4eaacd74a94c052e2e9db086253555686ae70d53f",
    strip_prefix = "rules_groovy-54cb1746d0832feca3a610fef7da92bbe6e7cbd4",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/54cb1746d0832feca3a610fef7da92bbe6e7cbd4.tar.gz"],
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")

groovy_repositories()

# For our go_image test.
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "6dcc2cb319da10d33a810f4b330896de9beebbdd3d3392f6a19cf32bcc1b908d",
    strip_prefix = "rules_go-0.12.0",
    urls = ["https://github.com/bazelbuild/rules_go/archive/0.12.0.tar.gz"],
)

load("@io_bazel_rules_go//go:def.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains()

# Have the go_image dependencies for testing.
load(
    "//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()

# For our rust_image test
http_archive(
    name = "io_bazel_rules_rust",
    sha256 = "615639cfd5459fec4b8a5751112be808ab25ba647c4c1953d29bb554ef865da7",
    strip_prefix = "rules_rust-0.0.6",
    urls = ["https://github.com/bazelbuild/rules_rust/archive/0.0.6.tar.gz"],
)

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

# For our d_image test
http_archive(
    name = "io_bazel_rules_d",
    sha256 = "527908e02d7bccf5a4eb89b690b003247eb6c57d69cc3234977c034d27c59d6e",
    strip_prefix = "rules_d-0400b9b054013274cee2ed15679da19e1fc94e07",
    urls = ["https://github.com/bazelbuild/rules_d/archive/0400b9b054013274cee2ed15679da19e1fc94e07.tar.gz"],
)

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()

http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = "a672bbb4eb8c49363942fe9a491f35214b5d7a0000c86e0152ea8cd3261b1c12",
    strip_prefix = "rules_nodejs-0.8.0",
    urls = ["https://github.com/bazelbuild/rules_nodejs/archive/0.8.0.tar.gz"],
)

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories", "npm_install")

node_repositories(package_json = ["//testdata:package.json"])

npm_install(
    name = "npm_deps",
    package_json = "//testdata:package.json",
)

load(
    "//nodejs:image.bzl",
    _nodejs_image_repos = "repositories",
)

_nodejs_image_repos()
