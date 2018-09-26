load("//container:providers.bzl", "RegistryCredentialInfo")

def write_docker_config_json_action(ctx, registry, credential, config_json = None):
    """Create an action that writes a docker config file.

    Args:
      ctx: the rule ctx object
      registry: the name of the registry to which the credential should be
      associated
      credential: a RegistryCredentialInfo struct
      config_json: path to the file where the config.json should be written.
      Defaults to %{credential.name}/.docker/config.json.

    Return: The config_json file 
    """
    if credential.type != "basic":
        fail("Unsupported docker credential type: %s" % credential.type)
    if not config_json:
        config_json = ctx.actions.declare_file("%s/.docker/config.json" % credential.name)
    # NOTE: ctx.actions.write does not work here as we need the
    # use_default_shell_env feature of the run_shell action.
    ctx.actions.run_shell(
        mnemonic = "WriteDockerConfig",
        inputs = [],
        outputs = [config_json],
        command = """
set -euo pipefail
cat <<EOF > "%s"
{
    "auths": {
        "%s": {
            "username": "${%s}",
            "password": "${%s}"
        }
    }
}
EOF
        """ % (config_json.path, registry, credential.user_env, credential.pass_env),
        use_default_shell_env = True,
    )
    return config_json


def _registry_credential_impl(ctx):
    """Implementation of the registry credential

    Provides the RegistryCredentialInfo object from given rule attributes.
    """
    return [RegistryCredentialInfo(
        name = ctx.label.name,
        user_env = ctx.attr.user_env,
        pass_env = ctx.attr.pass_env,
        type = ctx.attr.type,
    )]

registry_credential = rule(
    implementation = _registry_credential_impl,
    attrs = {
        "user_env": attr.string(
            doc ="Environment variable that contains the docker basic auth username",
            mandatory = True,
        ),
        "pass_env": attr.string(
            doc = "Environmemt variable that holds the docker basic auth password",
            mandatory = True,
        ),
        "type": attr.string(
            doc = "Credential type - only basic auth is currently supported",
            default = "basic",
            values = ["basic"],
        ),
    },
)
"""
Rule to declare a (basic auth) credential.  The credential may 
be used by the container_push and container_pull rules.

In order to avoid committing sensitive information to version control, 
the attributes 'user_env' and 'pass_env' name environment variables that 
hold the basic auth username and password.  

The `--action_env` flag is mandatory to use this feature.  Without it, 
the environment variables will not be visible to the action that 
requires it.  Example:

Define a registry credential:

```python
load("@io_bazel_rules_docker//container:container.bzl", "registry_credential")
registry_credential(
    name = "private",
    user_env = "PRIVATE_REGISTRY_USERNAME",
    pass_env = "PRIVATE_REGISTRY_PASSWORD",
)
```

```python
container_push(
    name = "push",
    registry = "private.container-registry.io",
    repository = "path/to/my/repo",
    tag = "latest",
    credential = ":private",
)
```

Finally, add the following to your .bazelrc file:

```
build --action_env=PRIVATE_REGISTRY_USERNAME
build --action_env=PRIVATE_REGISTRY_PASSWORD
```

In this scenario, a `private/.docker/config.json` 
file will be written and passed to the pusher tool as 
`pusher.par --client-config private/.docker/config.json ...` 
at runtime.
"""
