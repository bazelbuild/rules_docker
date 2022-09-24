load("@io_bazel_rules_docker//container:pull.bzl",
    _container_pull="container_pull")

# Call container_pull with the docker client config directory set.
def container_pull(**kwargs):
    if "docker_client_config" in kwargs:
        fail("docker_client_config attribute should not be set on the container_pull created by the custom docker toolchain configuration")
    _container_pull(
        docker_client_config="%{docker_client_config}",
        cred_helpers=%{cred_helpers},
        **kwargs
    )
