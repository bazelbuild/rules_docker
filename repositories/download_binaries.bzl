"""Register external repositories for go_puller and structure_test binaries.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

RULES_DOCKER_GO_BINARY_RELEASE = "aad94363e63d31d574cf701df484b3e8b868a96a"

def download_go_puller():
    maybe(
        http_file,
        name = "go_puller_linux_amd64",
        executable = True,
        sha256 = "08b8963cce9234f57055bafc7cadd1624cdce3c5990048cea1df453d7d288bc6",
        urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-linux-amd64")],
    )

    maybe(
        http_file,
        name = "go_puller_linux_arm64",
        executable = True,
        sha256 = "912ee7c469b3e4bf15ba5d1f0ee500e7ec6724518862703fa8b09e4d58ce3ee6",
        urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-linux-arm64")],
    )

    maybe(
        http_file,
        name = "go_puller_linux_s390x",
        executable = True,
        sha256 = "a5527b7b3b4a266e4680a4ad8939429665d4173f26b35d5d317385134369e438",
        urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-linux-s390x")],
    )

    maybe(
        http_file,
        name = "go_puller_darwin",
        executable = True,
        sha256 = "4855c4f5927f8fb0f885510ab3e2a166d5fa7cde765fbe9aec97dc6b2761bb22",
        urls = [("https://storage.googleapis.com/rules_docker/" + RULES_DOCKER_GO_BINARY_RELEASE + "/puller-darwin-amd64")],
    )

def download_structure_test():
    maybe(
        http_file,
        name = "structure_test_linux",
        executable = True,
        sha256 = "1524da5fd5a0fc88c4c9257a3de05a45f135df07e6a684380dd5f659b9ce189b",
        urls = ["https://storage.googleapis.com/container-structure-test/v1.11.0/container-structure-test-linux-amd64"],
    )

    maybe(
        http_file,
        name = "structure_test_linux_aarch64",
        executable = True,
        sha256 = "b376ff80134d2d609c591b98d65d653a514755b4861185fd93159af7062ec65d",
        urls = ["https://storage.googleapis.com/container-structure-test/v1.11.0/container-structure-test-linux-arm64"],
    )

    maybe(
        http_file,
        name = "structure_test_darwin",
        executable = True,
        sha256 = "0a4ac9e221a86cda6bb9fedb2a0dfdce56f918327b8881977ad787ea15d0e82f",
        urls = ["https://storage.googleapis.com/container-structure-test/v1.11.0/container-structure-test-darwin-amd64"],
    )
