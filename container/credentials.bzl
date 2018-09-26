load("//container:providers.bzl", "RegistryCredentialInfo")

# def write_docker_config_file(ctx, registry, credential, config_file):
#     auths = {}
#     if cred.type != "basic":
#         fail("Unsupported docker credential type: %s" % cred.type)
#     auths[registry] = struct(
#         username = cred.username,
#         password = cred.password,
#     )
#     config = struct(
#         auths = auths,
#     )
#     if not config_file:
#         config_file = ctx.actions.declare_file(".docker/config.json")
#     ctx.actions.write(config_file, config.to_json())
#     return config_file

def write_docker_config_fileOLD(ctx, registry, credential, config_file = None):
    if credential.type != "basic":
        fail("Unsupported docker credential type: %s" % credential.type)
    env = ctx.configuration.default_shell_env
    print("DEFAULT? CONFIGURATION ENV: %s" % ctx.configuration.default_shell_env)
    print("HOST CONFIGURATION ENV: %s" % ctx.host_configuration.default_shell_env)
    username = env.get(credential.uservar)
    if not username:
        fail("registry auth '%s': required environment variable '%s' is not defined (should contain basic auth username)\n%r" % (registry, credential.uservar, env))
    password = env.get(credential.passvar)
    if not password:
        fail("registry auth '%s': required environment variable '%s' is not defined (should contain basic auth password)\n%r" % (registry, credential.passvar, env))

    auths = {}
    auths[registry] = struct(
        username = username,
        password = password,
    )
    config = struct(
        auths = auths,
    )
    if not config_file:
        config_file = ctx.actions.declare_file(".docker/config.json")
    ctx.actions.write(config_file, config.to_json())
    return config_file

def write_docker_config_file(ctx, registry, credential, config_file = None):
    if credential.type != "basic":
        fail("Unsupported docker credential type: %s" % credential.type)
    # env = ctx.configuration.default_shell_env
    # print("DEFAULT? CONFIGURATION ENV: %s" % ctx.configuration.default_shell_env)
    # print("HOST CONFIGURATION ENV: %s" % ctx.host_configuration.default_shell_env)
    # username = env.get(credential.uservar)
    # if not username:
    #     fail("registry auth '%s': required environment variable '%s' is not defined (should contain basic auth username)\n%r" % (registry, credential.uservar, env))
    # password = env.get(credential.passvar)
    # if not password:
    #     fail("registry auth '%s': required environment variable '%s' is not defined (should contain basic auth password)\n%r" % (registry, credential.passvar, env))

    auths = {}
    auths[registry] = struct(
        username = "<USERNAME>",
        password = "<PASSWORD>",
    )
    config = struct(
        auths = auths,
    )
    if not config_file:
        config_file = ctx.actions.declare_file(".docker/config.json")
    ctx.actions.run_shell(
        mnemonic = "WriteDockerConfig",
        inputs = [],
        outputs = [config_file],
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
        """ % (config_file.path, registry, credential.uservar, credential.passvar),
        use_default_shell_env = True,
    )
    #ctx.actions.write(config_file, config.to_json())
    return config_file

def _registry_credential_impl(ctx):
    return [RegistryCredentialInfo(
        uservar = ctx.attr.uservar,
        passvar = ctx.attr.passvar,
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
        "sha256": attr.string(
            doc = "sha256 hash of username + password",
            mandatory = False,
        ),
        "type": attr.string(
            doc = "Docker credential type - only basic auth is currently supported",
            default = "basic",
            values = ["basic"],
        ),
    },
)


def _basic_auth_credential_impl(repository_ctx):
    env = repository_ctx.os.environ

    lines = [
        "# Generated - do not modify",
        'load("@io_bazel_rules_docker//container:credentials.bzl", "registry_credential")',
    ]

    uservar = repository_ctx.attr.uservar
    passvar = repository_ctx.attr.passvar

    username = env.get(uservar)
    if not username:
        fail("Mandatory environment variable '%s' is not defined (should contain basic auth username)" % uservar)
    password = env.get(passvar)
    if not password:
        fail("Mandatory environment variable '%s' is not defined (should contain basic auth password)" % passvar)

    script = [
        "import hashlib",
        "import sys",
        "print(hashlib.sha256(sys.argv[1]).hexdigest())"
    ]
    repository_ctx.file("sha256.py", "\n".join(script))

    python = repository_ctx.which("python")
    result = repository_ctx.execute([python, "./sha256.py", username + password], quiet = True)
    if result.return_code:
        fail("Failed to write userpass sha256: %s" % result.stderr)

    lines.append("registry_credential(")
    lines.append("    name = 'credential',")
    lines.append("    uservar = '%s'," % uservar)
    lines.append("    passvar = '%s'," % passvar)
    lines.append("    sha256 = '%s'," % result.stdout.strip())
    lines.append("    type = 'basic',")
    lines.append("    visibility = [")
    for e in repository_ctx.attr.visibility:
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

    basic_auth_credential(
        name="docker", 
        auths = {
            "gcr.io/my-container-registry": ["MYCR_USERNAME", "MYCR_PASSWORD"],
        },
    )

In the example above, DOCKER_URL will use the value 'index.docker.io' if the
"DOCKER_URL" environment variable is not set.

Then in build scripts you can reference these by importing a custom bzl file.

"""
def basic_auth_credential(**kwargs):
    _basic_auth_credential = repository_rule(
        implementation = _basic_auth_credential_impl,
        attrs = {
            "uservar": attr.string(
                mandatory = True,
                doc = "Name of environment variable that holds the basic auth username",
            ),
            "passvar": attr.string(
                mandatory = True,
                doc = "Name of environment variable that holds the basic auth password",
            ),
        },
        environ = [kwargs.get("uservar"), kwargs.get("passvar")],
    )
    _basic_auth_credential(**kwargs)