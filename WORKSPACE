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

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
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

load("//repositories:deps.bzl", container_deps = "deps")

container_deps()

# pip deps are only needed for running tests.
load("//repositories:pip_repositories.bzl", "pip_deps")

pip_deps()

load(
    "//container:new_pull.bzl",
    "new_container_pull",
)

# These are for testing the new container pull.
# For testing, don't change the sha.
new_container_pull(
    name = "new_alpine_linux_armv6_fixed_id",
    architecture = "arm",
    cpu_variant = "v6",
    digest = "sha256:f29c3d10359dd0e6d0c11e4f715735b678c0ab03a7ac4565b4b6c08980f6213b",
    os = "linux",
    registry = "index.docker.io",
    repository = "library/alpine",
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

# For testing, don't change the sha.
new_container_pull(
    name = "new_distroless_base_fixed_id",
    digest = "sha256:a26dde6863dd8b0417d7060c990abe85c1d2481541568445e82b46de9452cf0c",
    registry = "gcr.io",
    repository = "distroless/base",
)

new_container_pull(
    name = "new_alpine_linux_amd64",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

new_container_pull(
    name = "new_alpine_linux_amd64_tar",
    format = "docker",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

new_container_pull(
    name = "new_alpine_linux_ppc64le",
    architecture = "ppc64le",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

new_container_pull(
    name = "new_alpine_linux_ppc64le_tar",
    architecture = "ppc64le",
    format = "docker",
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

# These are for package_manager testing.
http_file(
    name = "bazel_gpg",
    sha256 = "30af2ca7abfb65987cd61802ca6e352aadc6129dfb5bfc9c81f16617bc3a4416",
    urls = ["https://bazel.build/bazel-release.pub.gpg"],
)

http_file(
    name = "launchpad_openjdk_gpg",
    sha256 = "54b6274820df34a936ccc6f5cb725a9b7bb46075db7faf0ef7e2d86452fa09fd",
    urls = ["http://keyserver.ubuntu.com/pks/lookup?op=get&fingerprint=on&search=0xEB9B1D8886F44E2A"],
)

container_load(
    name = "pause_tar",
    file = "//testdata:pause.tar",
)

load(
    "//container:new_load.bzl",
    "new_container_load",
)

# To test the new_container_load rule.
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

container_pull(
    name = "official_xenial",
    registry = "index.docker.io",
    repository = "library/ubuntu",
    tag = "16.04",
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

# This image is used by docker/util tests.
container_pull(
    name = "debian_base",
    digest = "sha256:00109fa40230a081f5ecffe0e814725042ff62a03e2d1eae0563f1f82eaeae9b",
    registry = "gcr.io",
    repository = "google-appengine/debian9",
)

# This image is used by tests/contrib tests.
container_pull(
    name = "bazel_0271",
    digest = "sha256:436708ebb76c0089b94c46adac5d3332adb8c98ef8f24cb32274400d01bde9e3",
    registry = "l.gcr.io",
    repository = "google/bazel",
)

# Have the py_image dependencies for testing.
load(
    "//python:image.bzl",
    _py_image_repos = "repositories",
)

_py_image_repos()

# base_images_docker is needed as ubuntu1604/debian9 is used in package_manager tests
http_archive(
    name = "base_images_docker",
    strip_prefix = "base-images-docker-8ef00ee3077ba555851f63431036d34ffda85a4c",
    urls = ["https://github.com/GoogleContainerTools/base-images-docker/archive/8ef00ee3077ba555851f63431036d34ffda85a4c.tar.gz"],
)

http_archive(
    name = "ubuntu1604",
    strip_prefix = "base-images-docker-8ef00ee3077ba555851f63431036d34ffda85a4c/ubuntu1604",
    urls = ["https://github.com/GoogleContainerTools/base-images-docker/archive/8ef00ee3077ba555851f63431036d34ffda85a4c.tar.gz"],
)

http_archive(
    name = "debian9",
    strip_prefix = "base-images-docker-8ef00ee3077ba555851f63431036d34ffda85a4c/debian9",
    urls = ["https://github.com/GoogleContainerTools/base-images-docker/archive/8ef00ee3077ba555851f63431036d34ffda85a4c.tar.gz"],
)

load("@ubuntu1604//:deps.bzl", ubuntu1604_deps = "deps")

ubuntu1604_deps()

load("@debian9//:deps.bzl", debian9_deps = "deps")

debian9_deps()

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
    sha256 = "8d4c6b07281182fc63373d5f0eb38e22afe70d7b424a1f739a6c6b4458c3ea50",
    strip_prefix = "rules_scala-0b6cff39c30da5585394348883b36ba031584727",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/0b6cff39c30da5585394348883b36ba031584727.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load("@io_bazel_rules_scala//scala:toolchains.bzl", "scala_register_toolchains")

scala_register_toolchains()

# For our groovy_image test.
http_archive(
    name = "io_bazel_rules_groovy",
    sha256 = "1b6b21d24e641b166ccfeeedc70c2a211796ab91853304b1d80e032914b3bf05",
    strip_prefix = "rules_groovy-d3b1b862046513a50d1cde266f1443e888c92790",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/d3b1b862046513a50d1cde266f1443e888c92790.tar.gz"],
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
    sha256 = "e630980fc9f18febda89ce544fe7c3fe3bf31985bae283fbb55b1eff64bd9cdc",
    strip_prefix = "rules_rust-949b5d69a392fd14b60f7ee3aacc6d69706e6018",
    urls = ["https://github.com/bazelbuild/rules_rust/archive/949b5d69a392fd14b60f7ee3aacc6d69706e6018.tar.gz"],
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
    sha256 = "38ec4b3cd5079d81f3643bdb4f80e54e98b1005f39aa0f5f31323a3eae06db8e",
    strip_prefix = "bazel-toolchains-0.28.1",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/archive/0.28.1.tar.gz",
        "https://github.com/bazelbuild/bazel-toolchains/archive/0.28.1.tar.gz",
    ],
)

load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")

rbe_autoconfig(
    name = "buildkite_config",
)

# gazelle:repo bazel_gazelle
