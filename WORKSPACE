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

LANGUAGES = [
    {
        "name": "scala",
        "commit": "0bac7fe86fdde1cfba3bb2c8a04de5e12de47bcd",
        "sha256": "f5f35de94d2d64e48fb4aef87cf89248b8980cb25f9ff1449575af8d904f41be",
    },
    {
        "name": "groovy",
        "commit": "6b8e32ce0f7e33ae1b859706c2dc0c169b966e7e",
        "sha256": "ced0b80f4c32805abc61592eb2e5bd3e1ab809abdc24e39f888ce33055bfee5a",
    },
    {
        "name": "go",
        "commit": "74849e006b4f4392e95a12188cd0352b01730c3a",
        "sha256": "ac1ba9a8527ccb476440cb5eb754849ed3fcd9a0c5103d9ced047fa33ffcfffe",
    },
    {
        "name": "rust",
        "commit": "7b1ba1f2a89006fbe358e97011cb1c1516435806",
        "sha256": "69ce87d3697a9f2f092b4a07be2a85dbd472188173726702ca55c6e51d2ca0c9",
    },
    {
        "name": "d",
        "commit": "0400b9b054013274cee2ed15679da19e1fc94e07",
        "sha256": "527908e02d7bccf5a4eb89b690b003247eb6c57d69cc3234977c034d27c59d6e",
    },
]

[http_archive(
    name = "io_bazel_rules_{}".format(l["name"]),
    sha256 = l["sha256"],
    url = "https://github.com/bazelbuild/rules_{}/archive/{}.tar.gz".format(l["name"], l["commit"]),
    strip_prefix = "rules_{}-{}".format(l["name"], l["commit"]),
) for l in LANGUAGES]

# For our scala_image test.
load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")
scala_repositories()

# For our groovy_image test.
load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")
groovy_repositories()

# For our go_image test.
load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
go_rules_dependencies()
go_register_toolchains()

# Have the go_image dependencies for testing.
load(
    "//go:image.bzl",
    _go_image_repos = "repositories",
)
_go_image_repos()

# For our rust_image test
load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")
rust_repositories()

# For our d_image test
load("@io_bazel_rules_d//d:d.bzl", "d_repositories")
d_repositories()

# For our nodejs_image test.
NODEJS_COMMIT = "de5393f683b9a73d69d023ca0ffce8ed5d39fcfd"
http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = "bf92c7ae021eb0f17b2e9f1145390624a064c40d10f67bd604915de8d8c4b6a7",
    url = "https://github.com/bazelbuild/rules_nodejs/archive/{}.tar.gz".format(NODEJS_COMMIT),
    strip_prefix = "rules_nodejs-{}".format(NODEJS_COMMIT),
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
