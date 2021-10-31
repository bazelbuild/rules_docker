def docker_path(toolchain_info):
    """Resolve the user-supplied docker path, if any.

    Args:
       toolchain_info: The DockerToolchainInfo

    Returns:
       Path to docker
    """
    if toolchain_info.tool_target:
        return toolchain_info.tool_target.files_to_run.executable.path
    else:
        return toolchain_info.tool_path