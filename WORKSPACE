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
    sha256 = "94ea27b37c9194f35e02e2ce485a3fd39d7c2fa5343d157e0aeb0932de7839cd",
    strip_prefix = "rules_scala-09790bb54249ab8ad517cd696171bc50a8e8a218",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/09790bb54249ab8ad517cd696171bc50a8e8a218.tar.gz"],
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

# For our go_image test.
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "a82a352bffae6bee4e95f68a8d80a70e87f42c4741e6a448bec11998fcc82329",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/0.18.5/rules_go-0.18.5.tar.gz",
        "https://github.com/bazelbuild/rules_go/releases/download/0.18.5/rules_go-0.18.5.tar.gz",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains()

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

gazelle_dependencies()

# Have the go_image dependencies for testing.
load(
    "//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()

# For our rust_image test
http_archive(
    name = "io_bazel_rules_rust",
    sha256 = "11f0f6302a09b6fead4c0164b80cfd96ae2e3a2bc09e7f2ad080c95efa74178f",
    strip_prefix = "rules_rust-8a098fd1f043826ad48843543dca92642019c7ec",
    urls = ["https://github.com/bazelbuild/rules_rust/archive/8a098fd1f043826ad48843543dca92642019c7ec.tar.gz"],
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
    sha256 = "c0ebd591a02969587465108a7bc7b808092226a233e0685f14d57ff207ed4b08",
    strip_prefix = "rules_d-14e703dcbfaefd1b71914e7ea0369941c81e72c3",
    urls = ["https://github.com/bazelbuild/rules_d/archive/14e703dcbfaefd1b71914e7ea0369941c81e72c3.tar.gz"],
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
    name = "basic_dockerfile",
    build_args = {
        "ALPINE_version": "3.9",
    },
    dockerfile = "//contrib:Dockerfile",
)

# Register the default py_toolchain for containerized execution
register_toolchains("//toolchains/python:container_py_toolchain")

http_archive(
    name = "bazel_toolchains",
    sha256 = "d63355e9d35b34232fa6be517ee1a2df80c1e01b111507f9f3dca124c316be8b",
    strip_prefix = "bazel-toolchains-4b3f507f3104a69299c1fb8d242e4269fa50f5c5",
    urls = ["https://github.com/bazelbuild/bazel-toolchains/archive/4b3f507f3104a69299c1fb8d242e4269fa50f5c5.tar.gz"],
)

load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")
load("@bazel_toolchains//rules:environments.bzl", "clang_env")

# TODO(nlopezgi): use versions from a pin file once the container is made public
rbe_autoconfig(
    name = "buildkite_config",
    base_container_digest = "sha256:bc6a2ad47b24d01a73da315dd288a560037c51a95cc77abb837b26fef1408798",
    # Note that if you change the `digest`, you might also need to update the
    # `base_container_digest` to make sure asci-toolchain/nosla-ubuntu16_04-bazel-docker-gcloud:<digest>
    # and marketplace.gcr.io/google/rbe-ubuntu16-04:<base_container_digest> have the
    # same Clang and JDK installed.
    digest = "sha256:ab88c40463d782acc4289948fe0b1577de0b143a753cea35cac34535203f8ca7",
    env = clang_env(),
    registry = "gcr.io",
    repository = "asci-toolchain/nosla-ubuntu16_04-bazel-docker-gcloud",
)

go_repository(
    name = "com_github_google_go_containerregistry",
    commit = "1c6c7f61e8a5402b606c3c6db169fdcd1b0712b7",
    importpath = "github.com/google/go-containerregistry",
)
