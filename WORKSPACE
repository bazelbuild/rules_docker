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

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(
    "//toolchains/docker:toolchain.bzl",
    docker_toolchain_configure = "toolchain_configure",
)

docker_toolchain_configure(
    name = "docker_config",
    docker_path = "/usr/bin/docker",
)

# Consumers shouldn't need to do this themselves once WORKSPACE is
# instantiated recursively.
load(
    "//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "//container:container.bzl",
    "container_load",
    "container_pull",
)

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

container_pull(
    name = "alpine_linux_amd64",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "alpine_linux_armv6",
    architecture = "arm",
    cpu_variant = "v6",
    os = "linux",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "alpine_linux_ppc64le",
    architecture = "ppc64le",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "k8s_pause_arm64",
    architecture = "arm64",
    registry = "k8s.gcr.io",
    repository = "pause",
    tag = "3.1",
)

# For testing, don't change the sha on these ones
container_pull(
    name = "distroless_fixed_id",
    digest = "sha256:a26dde6863dd8b0417d7060c990abe85c1d2481541568445e82b46de9452cf0c",
    registry = "gcr.io",
    repository = "distroless/base",
)

# Same as above, different name
container_pull(
    name = "distroless_fixed_id_copy",
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

http_archive(
    name = "io_bazel_rules_python",
    sha256 = "3e55ec4f7e151b048e950965f956c1e0633fc76449905f40dba671574eac574c",
    strip_prefix = "rules_python-965d4b4a63e6462204ae671d7c3f02b25da37941",
    urls = ["https://github.com/bazelbuild/rules_python/archive/965d4b4a63e6462204ae671d7c3f02b25da37941.tar.gz"],
)

load("@io_bazel_rules_python//python:pip.bzl", "pip_import", "pip_repositories")

pip_repositories()

pip_import(
    name = "pip_deps",
    requirements = "//testdata:requirements-pip.txt",
)

load("@pip_deps//:requirements.bzl", "pip_install")

pip_install()

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

load("@bazel_tools//tools/build_defs/repo:jvm.bzl", "jvm_maven_import_external")

# For our java_image test.
jvm_maven_import_external(
    name = "com_google_guava_guava",
    artifact = "com.google.guava:guava:18.0",
    artifact_sha256 = "d664fbfc03d2e5ce9cab2a44fb01f1d0bf9dfebeccc1a473b1f9ea31f79f6f99",
    licenses = ["notice"],  # Apache 2.0
    server_urls = ["http://central.maven.org/maven2"],
)

# For our scala_image test.
http_archive(
    name = "io_bazel_rules_scala",
    sha256 = "684f5b251670d3e6fe179f16aa8c363e9b7f30a0b0b8f2927128a02a341a4653",
    strip_prefix = "rules_scala-7bc18d07001cbfd425c6761c8384c4e982d25a2b",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/7bc18d07001cbfd425c6761c8384c4e982d25a2b.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load("@io_bazel_rules_scala//scala:toolchains.bzl", "scala_register_toolchains")

scala_register_toolchains()

# For our groovy_image test.
http_archive(
    name = "io_bazel_rules_groovy",
    sha256 = "ec4913782aedfe879d24271caa78abef7d1f00a826365689b92f60c4fd8b2f9f",
    strip_prefix = "rules_groovy-aa7dbd7f5aef954c64b44355b096caef4289228f",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/aa7dbd7f5aef954c64b44355b096caef4289228f.tar.gz"],
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")

groovy_repositories()

# For our go_image test.
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "77dfd303492f2634de7a660445ee2d3de2960cbd52f97d8c0dffa9362d3ddef9",
    url = "https://github.com/bazelbuild/rules_go/releases/download/0.18.1/rules_go-0.18.1.tar.gz",
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

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
    sha256 = "2d16f6da563e4d926d3ef0753c8eef14d90e7dd43d28f956d587872a39af244c",
    strip_prefix = "rules_rust-5fa9b101a68ddd4a628462b8d2aae06c6cbbda15",
    urls = ["https://github.com/bazelbuild/rules_rust/archive/5fa9b101a68ddd4a628462b8d2aae06c6cbbda15.tar.gz"],
)

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

# The following is required by rules_rust, remove once
# https://github.com/bazelbuild/rules_rust/issues/167 is fixed
load("@io_bazel_rules_rust//:workspace.bzl", "bazel_version")

bazel_version(name = "bazel_version")

# For our d_image test
http_archive(
    name = "io_bazel_rules_d",
    sha256 = "c5ce0a1f6b034f6f46ae6b0dab92bb036a698ea0c9150fe21bf92a0fa4b9056c",
    strip_prefix = "rules_d-30d991496f2ac82356d837dff08b1f485fbff042",
    urls = ["https://github.com/bazelbuild/rules_d/archive/30d991496f2ac82356d837dff08b1f485fbff042.tar.gz"],
)

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()

http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = "9b72bb0aea72d7cbcfc82a01b1e25bf3d85f791e790ddec16c65e2d906382ee0",
    strip_prefix = "rules_nodejs-0.16.2",
    urls = ["https://github.com/bazelbuild/rules_nodejs/archive/0.16.2.zip"],
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
    sha256 = "56a6705ad96b8aaa3c4ac427ce29c5a83408a04e31ee4956c92362e11cfdf497",
    strip_prefix = "bazel-toolchains-5b435b8bb8723feb836fbbe9b553cc40dbc9ce4f",
    urls = ["https://github.com/bazelbuild/bazel-toolchains/archive/5b435b8bb8723feb836fbbe9b553cc40dbc9ce4f.tar.gz"],
)

load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")
load("@bazel_toolchains//rules:environments.bzl", "clang_env")

# TODO(nlopezgi): use versions from a pin file once the container is made public
rbe_autoconfig(
    name = "buildkite_config",
    base_container_digest = "sha256:da0f21c71abce3bbb92c3a0c44c3737f007a82b60f8bd2930abc55fe64fc2729",
    digest = "sha256:176d4c94865d46a5d4896121aeb7ab8a3216bd56cc784c8485051e9cdead72d4",
    env = clang_env(),
    registry = "gcr.io",
    repository = "asci-toolchain/nosla-ubuntu16_04-bazel-docker-gcloud",
)
