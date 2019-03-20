load("@io_bazel_rules_docker//container:container.bzl", "container_image")
load("@io_bazel_rules_docker//contrib:test.bzl", "container_test")

container_image(
    name = "extended_alpine",
    base = "@alpine_linux_amd64//image",
    cmd = ["World"],
    entrypoint = [
        "echo",
        "Hello",
    ],
    env = {
        "envVar": "My environment variable",
        "xyz": "321",
    },
    files = [
        "//extended/image_data:Data_file.txt",
        "//extended/image_data:More_data.txt",
        "//extended/image_data:file_to_copy.txt",
    ],
    labels = {
        "version": "7.7",
        "desc": "Description for version 7.7",
    },
    ports = [
        "8080/tcp",
        "9876/udp",
    ],
    symlinks = {
        "/usr/More_data.txt": "/More_data.txt",
    },
    tars = ["//extended/image_data:tarfile.tar"],
    volumes = [
        "/myVol1",
        "/usr/myVol2",
    ],
)

# Tests

container_test(
    name = "extended_alpine_bazel_test",
    configs = ["//extended/test_configs:extended_alpine.yaml"],
    image = ":extended_alpine",
)

container_test(
    name = "extended_alpine_dockerfile_test",
    configs = ["//extended/test_configs:extended_alpine.yaml"],
    driver = "tar",
    image = "@extended_alpine_dockerfile//image:dockerfile_image",
)
