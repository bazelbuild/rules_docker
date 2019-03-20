load("@base_images_docker//util:run.bzl", "container_run_and_commit")
load("@io_bazel_rules_docker//container:container.bzl", "container_image")
load("@io_bazel_rules_docker//contrib:test.bzl", "container_test")

container_run_and_commit(
    name = "java_python_install",
    commands = [
        "apt-get update",
        "apt-get install -y openjdk-8-jdk python python-dev python-pip python-virtualenv",
        "rm -rf /var/lib/apt/lists/*",
    ],
    image = "@ubuntu1604//image",
)

# Wrapper targets for the tarred images are required in order to be able to run
# commandTests in container_test targets.

container_image(
    name = "java_python_bazel_wrapper",
    base = ":java_python_install_commit.tar",
)

container_image(
    name = "java_python_dockerfile_wrapper",
    base = "@java_python_dockerfile//image:dockerfile_image.tar",
)

# Tests

container_test(
    name = "java_python_bazel_test",
    configs = ["//run_instruction/test_configs:java_python.yaml"],
    image = ":java_python_bazel_wrapper",
)

container_test(
    name = "java_python_dockerfile_test",
    configs = ["//run_instruction/test_configs:java_python.yaml"],
    image = ":java_python_dockerfile_wrapper",
)
