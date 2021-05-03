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

load("//repositories:images.bzl", test_images = "images")

test_images()

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
    digest = "sha256:69e70a79f2d41ab5d637de98c1e0b055206ba40a8145e7bddb55ccc04e13cf8f",
    os = "linux",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.13",
)

container_pull(
    name = "distroless_base_fixed_id",
    digest = "sha256:a26dde6863dd8b0417d7060c990abe85c1d2481541568445e82b46de9452cf0c",
    registry = "gcr.io",
    repository = "distroless/base",
)

container_pull(
    name = "alpine_linux_amd64_tar",
    digest = "sha256:954b378c375d852eb3c63ab88978f640b4348b01c1b3456a024a81536dafbbf4",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "alpine_linux_ppc64le_tar",
    architecture = "ppc64le",
    digest = "sha256:402d21757a03a114d273bbe372fa4b9eca567e8b6c332fa7ebf982b902207242",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "distroless_base",
    digest = "sha256:75f63d4edd703030d4312dc7528a349ca34d48bec7bd754652b2d47e5a0b7873",
    registry = "gcr.io",
    repository = "distroless/base",
)

container_pull(
    name = "distroless_cc",
    digest = "sha256:c33fbcd3f924892f2177792bebc11f7a7e88ccbc247f0d0a01a812692259503a",
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
    sha256 = "547ec71b61f94b07909969649d52ee069db9b0c55763d3add366ca7a30fb3f6d",
    urls = ["https://bazel.build/bazel-release.pub.gpg"],
)

container_load(
    name = "pause_tar",
    file = "//testdata:pause.tar",
)

container_pull(
    name = "alpine_linux_amd64",
    digest = "sha256:954b378c375d852eb3c63ab88978f640b4348b01c1b3456a024a81536dafbbf4",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "alpine_linux_armv6",
    architecture = "arm",
    cpu_variant = "v6",
    digest = "sha256:dabea2944dcc2b86482b4f0b0fb62da80e0673e900c46c0e03b45919881a5d84",
    os = "linux",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "alpine_linux_ppc64le",
    architecture = "ppc64le",
    digest = "sha256:402d21757a03a114d273bbe372fa4b9eca567e8b6c332fa7ebf982b902207242",
    registry = "index.docker.io",
    repository = "library/alpine",
    tag = "3.8",
)

container_pull(
    name = "k8s_pause_arm64",
    architecture = "arm64",
    digest = "sha256:f365626a556e58189fc21d099fc64603db0f440bff07f77c740989515c544a39",
    registry = "k8s.gcr.io",
    repository = "pause",
    tag = "3.1",
)

container_pull(
    name = "official_xenial",
    digest = "sha256:89fd38d069a9a369525ade2bfb6922e62422db58813fccac0ecc1e59dfab0a59",
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
    name = "bazel_320",
    digest = "sha256:08434856d8196632b936dd082b8e03bae0b41346299aedf60a0d481ab427a69f",
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
    sha256 = "eb50020790e22538676e17c0242b9272bdb5c81f7bc6b128a4abfa7ad31faf5b",
    strip_prefix = "base-images-docker-36456edd3cc5a4d17852439cdcb038022cd912e5/ubuntu1604",
    urls = ["https://github.com/GoogleContainerTools/base-images-docker/archive/36456edd3cc5a4d17852439cdcb038022cd912e5.tar.gz"],
)

http_archive(
    name = "debian9",
    sha256 = "eb50020790e22538676e17c0242b9272bdb5c81f7bc6b128a4abfa7ad31faf5b",
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
    server_urls = ["https://repo1.maven.org/maven2"],
)

# For our scala_image test.
http_archive(
    name = "io_bazel_rules_scala",
    sha256 = "ed1a62f9fb2cb8930dd026b761ff900599b4c786c6cb6b7b5f9ad418f312c272",
    strip_prefix = "rules_scala-0366fb23cb91fee2847a8358472278ddc9940c5f",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/0366fb23cb91fee2847a8358472278ddc9940c5f.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load("@io_bazel_rules_scala//scala:toolchains.bzl", "scala_register_toolchains")

scala_register_toolchains()

# For our groovy_image test.
http_archive(
    name = "io_bazel_rules_groovy",
    sha256 = "de0493c134f173eb5df37ba77a79f41bd60b5b179b69d9d81ec898e176c4f7c0",
    strip_prefix = "rules_groovy-03c36efcab27bf711fdea53baef565aa161bd74c",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/03c36efcab27bf711fdea53baef565aa161bd74c.tar.gz"],
)

load("@io_bazel_rules_groovy//groovy:repositories.bzl", "rules_groovy_dependencies")

rules_groovy_dependencies()

# Have the go_image dependencies for testing.
load(
    "//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()

# For our rust_image test
http_archive(
    name = "rules_rust",
    sha256 = "42e60f81e2b269d28334b73b70d02fb516c8de0c16242f5d376bfe6d94a3509f",
    strip_prefix = "rules_rust-58f709ffec90da93c4e622d8d94f0cd55cd2ef54",
    urls = [
        # Master branch as of 2021-02-04
        "https://github.com/bazelbuild/rules_rust/archive/58f709ffec90da93c4e622d8d94f0cd55cd2ef54.tar.gz",
    ],
)

load("@rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

# For our d_image test
http_archive(
    name = "io_bazel_rules_d",
    sha256 = "5cad228cf0a0f2e67deb08bfac1800e683854b4e13389376751d52f33e99df73",
    strip_prefix = "rules_d-7e3bab5bf72f70c773a7240c496301cf80c6d9ec",
    urls = ["https://github.com/bazelbuild/rules_d/archive/7e3bab5bf72f70c773a7240c496301cf80c6d9ec.tar.gz"],
)

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()

http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = "10fffa29f687aa4d8eb6dfe8731ab5beb63811ab00981fc84a93899641fd4af1",
    urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/2.0.3/rules_nodejs-2.0.3.tar.gz"],
)

load("@build_bazel_rules_nodejs//:index.bzl", "yarn_install")

yarn_install(
    name = "npm",
    package_json = "//testdata:package.json",
    symlink_node_modules = False,
    yarn_lock = "//testdata:yarn.lock",
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
    vars = [
        "SOME_VAR",
    ],
)

# Load the image tarball.
container_load(
    name = "loaded_dockerfile_image_docker",
    file = "@dockerfile_docker//image:dockerfile_image.tar",
)

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
    sha256 = "1adf7a8e9901287c644dcf9ca08dd8d67a69df94bedbd57a841490a84dc1e9ed",
    strip_prefix = "bazel-toolchains-5.0.0",
    urls = [
        "https://github.com/bazelbuild/bazel-toolchains/archive/v5.0.0.tar.gz",
    ],
)

# Define several exec property repo rules to be used in testing.
load("@bazel_toolchains//rules/exec_properties:exec_properties.bzl", "rbe_exec_properties")

# A standard RBE execution property set repo rule.
rbe_exec_properties(
    name = "exec_properties",
)

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")
load("@exec_properties//:constants.bzl", "DOCKER_SIBLINGS_CONTAINERS", "NETWORK_ON")

rbe_autoconfig(
    name = "buildkite_config",
    base_container_digest = "sha256:b4dad0bfc4951d619229ab15343a311f2415a16ef83bcaa55b44f4e2bf1cf635",
    digest = "sha256:565d0a20a4c6a4c65e219f22ae55c88b36755848ff133164bce2d443f5f6067d",
    exec_properties = dicts.add(DOCKER_SIBLINGS_CONTAINERS, NETWORK_ON),
    registry = "marketplace.gcr.io",
    repository = "google/bazel",
    use_legacy_platform_definition = False,
)

# gazelle:repo bazel_gazelle

# Python packages needed for tests

# TODO(mattmoor): Is there a clean way to override?
http_archive(
    name = "httplib2",
    build_file_content = """
py_library(
    name = "httplib2",
    srcs = glob(["**/*.py"]),
    data = ["cacerts.txt"],
    visibility = ["//visibility:public"],
)
""",
    sha256 = "f2f35e29e99e8d9bb5921c17ede6ee10bd5bd971f2cd0b3aaaa20088754f89ba",
    strip_prefix = "httplib2-0.18.1/python3/httplib2/",
    type = "tar.gz",
    urls = ["https://codeload.github.com/httplib2/httplib2/tar.gz/v0.18.1"],
)

# Used by oauth2client
# TODO(mattmoor): Is there a clean way to override?
http_archive(
    name = "six",
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
)
""",
    sha256 = "e24052411fc4fbd1f672635537c3fc2330d9481b18c0317695b46259512c91d5",
    strip_prefix = "six-1.9.0/",
    type = "tar.gz",
    urls = ["https://pypi.python.org/packages/source/s/six/six-1.9.0.tar.gz"],
)

# Used for authentication in containerregistry
# TODO(mattmoor): Is there a clean way to override?
http_archive(
    name = "oauth2client",
    build_file_content = """
py_library(
    name = "oauth2client",
    srcs = glob(["**/*.py"]),
    visibility = ["//visibility:public"],
    deps = [
        "@httplib2//:httplib2",
        "@six//:six",
    ],
)
""",
    sha256 = "7230f52f7f1d4566a3f9c3aeb5ffe2ed80302843ce5605853bee1f08098ede46",
    strip_prefix = "oauth2client-4.0.0/oauth2client/",
    type = "tar.gz",
    urls = ["https://codeload.github.com/google/oauth2client/tar.gz/v4.0.0"],
)

# For kotlin image test
http_archive(
    name = "io_bazel_rules_kotlin",
    sha256 = "fe32ced5273bcc2f9e41cea65a28a9184a77f3bc30fea8a5c47b3d3bfc801dff",
    strip_prefix = "rules_kotlin-legacy-1.3.0-rc4",
    type = "zip",
    urls = ["https://github.com/bazelbuild/rules_kotlin/archive/legacy-1.3.0-rc4.zip"],
)

load("@io_bazel_rules_kotlin//kotlin:kotlin.bzl", "kotlin_repositories", "kt_register_toolchains")

kotlin_repositories()

kt_register_toolchains()

# For API doc generation
http_archive(
    name = "io_bazel_stardoc",
    patches = [],
    sha256 = "f89bda7b6b696c777b5cf0ba66c80d5aa97a6701977d43789a9aee319eef71e8",
    strip_prefix = "stardoc-d93ee5347e2d9c225ad315094507e018364d5a67",
    urls = [
        "https://github.com/bazelbuild/stardoc/archive/d93ee5347e2d9c225ad315094507e018364d5a67.tar.gz",
    ],
)
