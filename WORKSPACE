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

load("//skylib:java_configure.bzl", "java_configure")

java_configure()

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

# For testing, don't change the sha on these ones
container_pull(
    name = "distroless_fixed_id",
    digest = "sha256:a26dde6863dd8b0417d7060c990abe85c1d2481541568445e82b46de9452cf0c",
    registry = "gcr.io",
    repository = "distroless/base",
)

container_pull(
    name = "distroless_fixed_id_2",
    digest = "sha256:0268d76902d552257aa68b5f5d55ba8a37db92b3fed9c1cb222158732231b513",
    registry = "gcr.io",
    repository = "distroless/base",
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
    sha256 = "50465838809fee66cab66fa20ed3d68c667f663958ede10fbe504a0d18481016",
    strip_prefix = "rules_scala-5874a2441596fe9a0bf80e167a4d7edd945c221e",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/5874a2441596fe9a0bf80e167a4d7edd945c221e.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load("@io_bazel_rules_scala//scala:toolchains.bzl", "scala_register_toolchains")

scala_register_toolchains()

# For our groovy_image test.
http_archive(
    name = "io_bazel_rules_groovy",
    sha256 = "0d3f1f854d2d6fb79ef94bee6f6c23621fdc0032d72db11652a829bcb4777398",
    strip_prefix = "rules_groovy-ad6e2a1258a1f67e1a294b114d5dcbba36322a70",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/ad6e2a1258a1f67e1a294b114d5dcbba36322a70.tar.gz"],
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")

groovy_repositories()

# For our go_image test.
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "50207a04b74fe30218b06ac4467ea3862b9a3c99d3df7686be0eae02108ea06f",
    strip_prefix = "rules_go-0.13.0",
    urls = ["https://github.com/bazelbuild/rules_go/archive/0.13.0.tar.gz"],
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
    sha256 = "779edee08986ab40dbf8b1ad0260f3cc8050f1e96ccd2a88dc499848bbdb787f",
    strip_prefix = "rules_nodejs-0.11.1",
    urls = ["https://github.com/bazelbuild/rules_nodejs/archive/0.11.1.zip"],
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

http_archive(
    name = "bazel_toolchains",
    sha256 = "cefb6ccf86ca592baaa029bcef04148593c0efe8f734542f10293ea58f170715",
    strip_prefix = "bazel-toolchains-cdea5b8675914d0a354d89f108de5d28e54e0edc",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/archive/cdea5b8675914d0a354d89f108de5d28e54e0edc.tar.gz",
        "https://github.com/bazelbuild/bazel-toolchains/archive/cdea5b8675914d0a354d89f108de5d28e54e0edc.tar.gz",
    ],
)
