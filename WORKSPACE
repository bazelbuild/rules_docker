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
    "//repositories:go_repositories.bzl",
    container_go_deps = "go_deps",
)

container_go_deps()

load(
    "//container:new_pull.bzl",
    "new_container_pull",
)

# These are for testing the new container push
new_container_pull(
    name = "new_alpine_linux_armv6",
    architecture = "arm",
    cpu_variant = "v6",
    os = "linux",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

new_container_pull(
    name = "new_distroless_base",
    registry = "gcr.io",
    repository = "distroless/base",
)

new_container_pull(
    name = "new_alpine_linux_armv6_tar",
    architecture = "arm",
    cpu_variant = "v6",
    format = "docker",
    os = "linux",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

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

load(
    "//container:new_load.bzl",
    "new_container_load",
)

new_container_load(
    name = "new_pause_tar",
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
    sha256 = "9a3d71e348da504a9c4c5e8abd4cb822f7afb32c613dc6ee8b8535333a81a938",
    strip_prefix = "rules_python-fdbb17a4118a1728d19e638a5291b4c4266ea5b8",
    urls = ["https://github.com/bazelbuild/rules_python/archive/fdbb17a4118a1728d19e638a5291b4c4266ea5b8.tar.gz"],
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
    sha256 = "8dfa9a04a150f84cd6f7bc2f02be1e20f7301997926cd1ea75dec8fc9ecaca92",
    strip_prefix = "rules_scala-8092d5f6165a8d9c4797d5f089c1ba4eee3326b1",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/8092d5f6165a8d9c4797d5f089c1ba4eee3326b1.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load("@io_bazel_rules_scala//scala:toolchains.bzl", "scala_register_toolchains")

scala_register_toolchains()

# For our groovy_image test.
http_archive(
    name = "io_bazel_rules_groovy",
    sha256 = "f5eceb2fb2339747c0d9e5a869d4e03f420e533de1562823109c2e93ea651638",
    strip_prefix = "rules_groovy-1c39931457a04665fccecce78f953691b52187fc",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/1c39931457a04665fccecce78f953691b52187fc.tar.gz"],
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")

groovy_repositories()

# Have the go_image dependencies for testing.
load(
    "//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()

# For our rust_image test
http_archive(
    name = "io_bazel_rules_rust",
    sha256 = "299108772020c103eefacb4de30873d45224e8e0e6c11df7b56ffd11d959e212",
    strip_prefix = "rules_rust-3fac9fe0001d2a829d8ddaf3033b5171c049abdb",
    urls = ["https://github.com/bazelbuild/rules_rust/archive/3fac9fe0001d2a829d8ddaf3033b5171c049abdb.tar.gz"],
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
    sha256 = "bf8d7e7d76f4abef5a732614ac06c0ccffbe5aa5fdc983ea4fa3a81ec68e1f8c",
    strip_prefix = "rules_d-0579d30b7667a04b252489ab130b449882a7bdba",
    urls = ["https://github.com/bazelbuild/rules_d/archive/0579d30b7667a04b252489ab130b449882a7bdba.tar.gz"],
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

# For dockerfile_image rule tests
load("//contrib:dockerfile_build.bzl", "dockerfile_image")

dockerfile_image(
    name = "dockerfile_docker",
    build_args = {
        "ALPINE_version": "3.9",
    },
    dockerfile = "//testdata/dockerfile_build:Dockerfile",
)

[dockerfile_image(
    name = "dockerfile_kaniko_%s" % tag,
    build_args = {
        "ALPINE_version": "3.9",
    },
    dockerfile = "//testdata/dockerfile_build:Dockerfile",
    driver = "kaniko",
    kaniko_tag = tag,
) for tag in [
    "latest",
    "debug",
]]

# Load the image tarball.
[container_load(
    name = "loaded_dockerfile_image_%s" % driver,
    file = "@dockerfile_%s//image:dockerfile_image.tar" % driver,
) for driver in [
    "docker",
    "kaniko_latest",
    "kaniko_debug",
]]

# Register the default py_toolchain for containerized execution
register_toolchains("//toolchains/python:container_py_toolchain")

http_archive(
    name = "bazel_toolchains",
    sha256 = "4598bf5a8b4f5ced82c782899438a7ba695165d47b3bf783ce774e89a8c6e617",
    strip_prefix = "bazel-toolchains-0.27.0",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/archive/0.27.0.tar.gz",
        "https://github.com/bazelbuild/bazel-toolchains/archive/0.27.0.tar.gz",
    ],
)

load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")

rbe_autoconfig(
    name = "buildkite_config",
)

# gazelle:repo bazel_gazelle
