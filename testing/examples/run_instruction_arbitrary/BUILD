load("@base_images_docker//util:run.bzl", "container_run_and_commit")
load("@io_bazel_rules_docker//container:container.bzl", "container_image", "container_layer")
load("@io_bazel_rules_docker//contrib:test.bzl", "container_test")

# Includes the gcloud installation archive
container_layer(
    name = "gcloud-layer",
    tars = [
        "@gcloud_archive//file",
    ],
)

# Build an image that uses the official bazel base image and includes the
# gcloud layer on top
container_image(
    name = "gcloud_installer",
    base = "@bazel_image//image",
    cmd = "",
    entrypoint = "",
    layers = [":gcloud-layer"],
)

# Bootstrap the container image by installing some additional
# packages and running some post install steps
container_run_and_commit(
    name = "gcloud_install",
    commands = [
        # Finalize the gcloud installation
        "/google-cloud-sdk/install.sh -q",
        # Add the gcloud binaries to PATH
        "echo 'source /google-cloud-sdk/path.bash.inc' >> ~/.bashrc",
        # Install kubernetes as a component of gcloud
        "/google-cloud-sdk/bin/gcloud components install --quiet kubectl",
        "apt-get update",
        "apt-get install -y --no-install-recommends python-pip",
        "apt-get clean",
        "python -m pip install --upgrade pip setuptools wheel",
    ],
    image = ":gcloud_installer.tar",
)

# Wrapper targets for the tarred images are required in order to be able to run
# commandTests in container_test targets.

container_image(
    name = "bazel_gcloud_bazel_wrapper",
    base = ":gcloud_install_commit.tar",
    env = {"PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/google-cloud-sdk/bin"},
)

container_image(
    name = "bazel_gcloud_dockerfile_wrapper",
    base = "@bazel_gcloud_dockerfile//image:dockerfile_image.tar",
)

# Tests

container_test(
    name = "bazel_gcloud_bazel_test",
    configs = ["//run_instruction_arbitrary/test_configs:bazel_gcloud.yaml"],
    image = ":bazel_gcloud_bazel_wrapper",
)

container_test(
    name = "bazel_gcloud_dockerfile_test",
    configs = ["//run_instruction_arbitrary/test_configs:bazel_gcloud.yaml"],
    image = ":bazel_gcloud_dockerfile_wrapper",
)
