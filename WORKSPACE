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
    "//container:container.bzl",
    "container_load",
    "container_pull",
)

# For testing, don't change the sha.
container_pull(
    name = "alpine_linux_armv6_fixed_id",
    architecture = "arm",
    cpu_variant = "v6",
    digest = "sha256:f29c3d10359dd0e6d0c11e4f715735b678c0ab03a7ac4565b4b6c08980f6213b",
    os = "linux",
    registry = "index.docker.io",
    repository = "library/alpine",
)

container_pull(
    name = "alpine_linux_armv6_tar",
    architecture = "arm",
    cpu_variant = "v6",
    os = "linux",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "distroless_base_fixed_id",
    digest = "sha256:a26dde6863dd8b0417d7060c990abe85c1d2481541568445e82b46de9452cf0c",
    registry = "gcr.io",
    repository = "distroless/base",
)

container_pull(
    name = "alpine_linux_amd64_tar",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "alpine_linux_ppc64le_tar",
    architecture = "ppc64le",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

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

container_pull(
    name = "large_image_timeout_test",
    digest = "sha256:8f995ea7676177aebdb7fc1c8f7d285c290e6e1247b35356ade0e9e8ec628828",
    registry = "l.gcr.io",
    repository = "google/bazel",
)

# These are for package_manager testing.
http_file(
    name = "bazel_gpg",
    sha256 = "30af2ca7abfb65987cd61802ca6e352aadc6129dfb5bfc9c81f16617bc3a4416",
    urls = ["https://bazel.build/bazel-release.pub.gpg"],
)

http_file(
    name = "launchpad_openjdk_gpg",
    sha256 = "32e2f5ceda14f8929d189f66efe6aa98c77e7f7e4e728b35973e7239f2456017",
    urls = ["http://keyserver.ubuntu.com/pks/lookup?op=get&fingerprint=on&search=0xEB9B1D8886F44E2A"],
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
    name = "bazel_0291",
    digest = "sha256:957c063f1296220c55d640ce82542b4c50d7a75b968fa3fd104e5cf293391ede",
    registry = "l.gcr.io",
    repository = "google/bazel",
)

# End to end test for the puller to download an image with 11 layers.
container_pull(
    name = "e2e_test_pull_image_with_11_layers",
    registry = "localhost:5000",
    repository = "tests/container/image_with_11_layers",
    tag = "latest",
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
    strip_prefix = "base-images-docker-36456edd3cc5a4d17852439cdcb038022cd912e5",
    urls = ["https://github.com/GoogleContainerTools/base-images-docker/archive/36456edd3cc5a4d17852439cdcb038022cd912e5.tar.gz"],
)

http_archive(
    name = "ubuntu1604",
    strip_prefix = "base-images-docker-36456edd3cc5a4d17852439cdcb038022cd912e5/ubuntu1604",
    urls = ["https://github.com/GoogleContainerTools/base-images-docker/archive/36456edd3cc5a4d17852439cdcb038022cd912e5.tar.gz"],
)

http_archive(
    name = "debian9",
    strip_prefix = "base-images-docker-36456edd3cc5a4d17852439cdcb038022cd912e5/debian9",
    urls = ["https://github.com/GoogleContainerTools/base-images-docker/archive/36456edd3cc5a4d17852439cdcb038022cd912e5.tar.gz"],
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
    sha256 = "70ade55ddd2762d32651840c9f74a6df945909bad4da0f277b72d79f19cb339b",
    strip_prefix = "rules_scala-26cf9b74fc46f1e9a970c97837447549ed7257b6",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/26cf9b74fc46f1e9a970c97837447549ed7257b6.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load("@io_bazel_rules_scala//scala:toolchains.bzl", "scala_register_toolchains")

scala_register_toolchains()

# For our groovy_image test.
http_archive(
    name = "io_bazel_rules_groovy",
    sha256 = "d2047c66847108f8514cb391ef981e11abd6625c267b156ca4b70345ca196574",
    strip_prefix = "rules_groovy-ce90de1cde0366229c6fc14bed1e00c2a485c2d8",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/ce90de1cde0366229c6fc14bed1e00c2a485c2d8.tar.gz"],
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
    sha256 = "69b67e19532b12da3edccda404772e85a788d16ae739343f5338dd340a0fba2e",
    strip_prefix = "rules_rust-ec436b5ff2ab1ddeba6f27a7a1a5d263812981a6",
    urls = ["https://github.com/bazelbuild/rules_rust/archive/ec436b5ff2ab1ddeba6f27a7a1a5d263812981a6.tar.gz"],
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
    sha256 = "3d7296d834208792fa3b2ded8ec04e75068e3de172fae79db217615bd75a6ff7",
    urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/0.39.1/rules_nodejs-0.39.1.tar.gz"],
)

load("@build_bazel_rules_nodejs//:index.bzl", "node_repositories", "npm_install")

node_repositories(package_json = ["//testdata:package.json"])

npm_install(
    name = "npm_deps",
    package_json = "//testdata:package.json",
    package_lock_json = "//testdata:package-lock.json",
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

# Register the default py_toolchain / platform for containerized execution
register_toolchains(
    "//toolchains:container_py_toolchain",
)

register_execution_platforms(
    "@local_config_platform//:host",
    "//platforms:local_container_platform",
)

http_archive(
    name = "bazel_toolchains",
    sha256 = "eea054525c8b8d9aa129d0e03fc02ef47c85eea2884c4dba3700b63e01f2b192",
    strip_prefix = "bazel-toolchains-1.1.1",
    urls = [
        "https://github.com/bazelbuild/bazel-toolchains/archive/1.1.1.tar.gz",
    ],
)

# Define several exec property repo rules to be used in testing.
load(
    "@bazel_toolchains//rules/exec_properties:exec_properties.bzl",
    "merge_dicts",
    "rbe_exec_properties",
)

# A standard RBE execution property set repo rule.
rbe_exec_properties(
    name = "exec_properties",
)

load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")
load("@exec_properties//:constants.bzl", "DOCKER_SIBLINGS_CONTAINERS", "NETWORK_ON")

rbe_autoconfig(
    name = "buildkite_config",
    base_container_digest = "sha256:4bfd33aa9ce73e28718385b8c01608a79bc6546906f01cf9329311cace1766a1",
    digest = "sha256:c20046852a2d7910c55d76e0ec9c182b37532a9f0360d22dd5c9a1451b7c3a15",
    exec_properties = merge_dicts(DOCKER_SIBLINGS_CONTAINERS, NETWORK_ON),
    registry = "marketplace.gcr.io",
    repository = "google/bazel",
    use_legacy_platform_definition = False,
)

# gazelle:repo bazel_gazelle
