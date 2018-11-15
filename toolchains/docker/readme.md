# Docker Toolchain

## Overview
This section describes how to use the Docker toolchain rules. You should continue
reading this README if any of the following apply to you:-
1. You wish to write a new bazel rule that uses docker
2. You wish to extend rules from this repository that are using the docker toolchain. You'll know if
   your underlying rules is using the docker toolchain but you didn't properly configure it if you see one of the following
   errors
   ```
    In <rule name> rule <build target>, toolchain type
    @io_bazel_rules_docker//toolchains/docker:toolchain_type was requested but only types [] are configured
   ```
   or
   ```
   no matching toolchains found for @io_bazel_rules_docker//toolchains/docker:toolchain_type
   ```
First read the official Bazel toolchain docs [here](https://docs.bazel.build/versions/master/toolchains.html) on how toolchain
rules work. After that read [How to use the Docker Toolchain](#how-to-use-the-docker-toolchain)

## How to use the Docker Toolchain
Register the toolchains exported by this repository in your WORKSPACE
```python
register_toolchains(
    "@io_bazel_rules_docker//toolchains/docker:default_linux_toolchain",
    "@io_bazel_rules_docker//toolchains/docker:default_windows_toolchain",
    "@io_bazel_rules_docker//toolchains/docker:default_osx_toolchain",
)
```

The docker toolchain automatically configures itself to use the docker in your
system path. To override this behavior, you need to explicitly call the
toolchain configuration function described [here](../../README.md#setup)

Declare the docker toolchain as a requirement in your rule
```python
your_rule = rule(
    attrs=...,
    ...
    toolchains=["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation=_impl
)
```

Use the rule as follows in the rule implementation method
```python
def _impl(ctx):
    # Get the DockerToolchainInfo provider
    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info
    # Path to the docker tool
    docker_path = toolchain_info.tool_path
    ...
```
See [toolchain.bzl](toolchain.bzl) for the definition of the DockerToolchainInfo provider