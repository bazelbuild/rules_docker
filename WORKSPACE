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
    name = "k8s_pause_amd64",
    # this is a manifest list, so the resolved digest should not match this digest
    digest = "sha256:f78411e19d84a252e53bff71a4407a5686c46983a2c2eeed83929b888179acea",
    registry = "k8s.gcr.io",
    repository = "pause",
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
    sha256 = "da960ee6f0e2e08556d0e0c307896b0ea6ebc8d86f50c649ceda361b71df74a1",
    strip_prefix = "rules_python-f3a6a8d00a51a1f0e6d61bc7065c19fea2b3dd7a",
    urls = ["https://github.com/bazelbuild/rules_python/archive/f3a6a8d00a51a1f0e6d61bc7065c19fea2b3dd7a.tar.gz"],
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
    sha256 = "902e30b931ded41905641895b90c41727e01a732aba67dfda604b764c1e1e494",
    strip_prefix = "rules_scala-1354d935a74395b3f0870dd90a04e0376fe22587",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/1354d935a74395b3f0870dd90a04e0376fe22587.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load("@io_bazel_rules_scala//scala:toolchains.bzl", "scala_register_toolchains")

scala_register_toolchains()

# For our groovy_image test.
http_archive(
    name = "io_bazel_rules_groovy",
    sha256 = "22669b0379e496555f574612043c6c3f1f6145c18d2697ddd308937d6d96f9ad",
    strip_prefix = "rules_groovy-cb174f4e7d6b9cbda06d4a0f538214f947747736",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/cb174f4e7d6b9cbda06d4a0f538214f947747736.tar.gz"],
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")

groovy_repositories()

# For our go_image test.
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "62ec3496a00445889a843062de9930c228b770218c735eca89c67949cd967c3f",
    url = "https://github.com/bazelbuild/rules_go/releases/download/0.16.4/rules_go-0.16.4.tar.gz",
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
    sha256 = "ed0c81084bcc2bdcc98cfe56f384b20856840825f5e413e2b71809b61809fc87",
    strip_prefix = "rules_rust-f32695dcd02d9a19e42b9eb7f29a24a8ceb2b858",
    urls = ["https://github.com/bazelbuild/rules_rust/archive/f32695dcd02d9a19e42b9eb7f29a24a8ceb2b858.tar.gz"],
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
    sha256 = "873022774f2f31ab57e7ff36b3f39c60fd4209952bfcc6902924b7942fa2973d",
    strip_prefix = "rules_d-2d38613073f3eb138aee0acbcb395ebada2f8ebf",
    urls = ["https://github.com/bazelbuild/rules_d/archive/2d38613073f3eb138aee0acbcb395ebada2f8ebf.tar.gz"],
)

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()

http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = "54ce360f02e2078150135fb139c482da702d5814294fb58e25d8536a66bba5eb",
    strip_prefix = "rules_nodejs-0f6201a9c70e7051881211c3855df9d493b06f02",
    urls = ["https://github.com/bazelbuild/rules_nodejs/archive/0f6201a9c70e7051881211c3855df9d493b06f02.tar.gz"],
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
    sha256 = "767325343fb2e3a8dd77bccff30cfa66056e88049d339a977f77a85ecc3fc580",
    strip_prefix = "bazel-toolchains-ad7f0157e13d5d3a4b893652a375b03ee9e032b4",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/archive/ad7f0157e13d5d3a4b893652a375b03ee9e032b4.tar.gz",
        "https://github.com/bazelbuild/bazel-toolchains/archive/ad7f0157e13d5d3a4b893652a375b03ee9e032b4.tar.gz",
    ],
)
