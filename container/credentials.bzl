load("//container:providers.bzl", "RegistryCredentialInfo")

def write_docker_config_file(ctx, registry, credential, config_file):
    auths = {}
    if cred.type != "basic":
        fail("Unsupported docker credential type: %s" % cred.type)
    auths[registry] = struct(
        username = cred.username,
        password = cred.password,
    ))
    config = struct(
        auths = auths,
    )
    if not config_file:
        config_file = ctx.actions.declare_file(".docker/config.json")
    ctx.actions.write(config_file, config.to_json())
    return config_file

def write_docker_config_file2(ctx, registry, credential, config_file):
    auths = {}
    if cred.type != "basic":
        fail("Unsupported docker credential type: %s" % cred.type)
    env = ctx.host_configuration.default_shell_env
    username = env.get(cred.uservar)
    password = env.get(cred.passvar)
    auths[registry] = struct(
        username = username,
        password = password,
    ))
    config = struct(
        auths = auths,
    )
    if not config_file:
        config_file = ctx.actions.declare_file(".docker/config.json")
    ctx.actions.write(config_file, config.to_json())
    return config_file

def _registry_credential_impl(ctx):
    return [RegistryCredentialInfo(
        address = ctx.attr.address,
        username = ctx.attr.username,
        password = ctx.attr.password,
        type = ctx.attr.type,
    )]

registry_credential = rule(
    implementation = _registry_credential_impl,
    attrs = {
        "uservar": attr.string(
            doc ="Docker basic auth username",
            mandatory = True,
        ),
        "passvar": attr.string(
            doc = "Docker basic auth password",
            mandatory = True,
        ),
        "type": attr.string(
            doc = "Docker credential type - only basic auth is currently supported",
            default = "basic",
            values = ["basic"],
        ),
    },
)


def _get_config_name(address):
    return address.replace("/", "_")


def _registry_basic_auth_credential_impl(repository_ctx):
    env = repository_ctx.os.environ

    lines = [
        "# Generated - do not modify",
        'load("@io_bazel_rules_docker//container:credential.bzl", "registry_credential")',
    ]

    uservar = ctx.attr.uservar
    passvar = ctx.attr.passvar
    username = env.get(ctx.attr.username),
    if not username:
        fail("docker auth '%s': required environment variable '%s' is not defined (should contain basic auth username)" % uservar)
    password = env.get(passvar)
    if not password:
        fail("docker auth '%s': required environment variable '%s' is not defined (should contain basic auth password)" % passvar)

    lines.append("registry_credential(")
    lines.append("    name = 'credential',")
    lines.append("    registry = '%s'," % ctx.attr.registry)
    lines.append("    username = '%s'," % username)
    lines.append("    password = '%s'," % password)
    lines.append("    type = 'basic',")
    lines.append("    visibility = [")
    for e in ctx.attr.visibility:
        lines.append("        '%s'," % e)
    lines.append("    ],")
    lines.append(")")

    repository_ctx.file("BUILD.bazel", "\n".join(lines))

"""

Explicitly import secrets from the environment into the workspace. The 'entries'
is a string -> string key/value mapping such that the key is the name of the
environment variable to import.  If the value is the special token '<REQUIRED>'
the build will fail if the variable is unset or empty.  Otherwise the value will
be used as the default.

    registry_basic_auth_credential(
        name="docker", 
        auths = {
            "gcr.io/my-container-registry": ["MYCR_USERNAME", "MYCR_PASSWORD"],
        },
    )

In the example above, DOCKER_URL will use the value 'index.docker.io' if the
"DOCKER_URL" environment variable is not set.

Then in build scripts you can reference these by importing a custom bzl file.

"""
def registry_basic_auth_credential(**kwargs):
    _registry_basic_auth_credential = repository_rule(
        implementation = _registry_basic_auth_credential_impl,
        attrs = {
            "registry": attr.string(
                mandatory = True,
                doc = "The name of the container registry to which this credential applies",
            ),
            "uservar": attr.string(
                mandatory = True,
                doc = "Name of environment variable that holds the basic auth username",
            ),
            "passvar": attr.string(
                mandatory = True,
                doc = "Name of environment variable that holds the basic auth password",
            ),
            "visibility": attr.string_list(
                default = ["//visibility:public"],
            ),
        },
        environ = [kwargs.get("username"), kwargs.get("password")],
    )
    _registry_basic_auth_credential(**kwargs)