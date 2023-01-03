"""bzlmod extension for container_pull.
"""

load("//container:pull.bzl", "container_pull", "container_pull_attrs")

_tag_attrs = {
    "name": attr.string(
        mandatory = True,
        doc = "The name of the repo.",
    ),
}
_tag_attrs.update(**container_pull_attrs)
_pull_tag = tag_class(attrs = _tag_attrs)

def _impl(ctx):
    for mod in ctx.modules:
        for tag in mod.tags.pull:
            container_pull(
                name = tag.name,
                architecture = tag.architecture,
                cpu_variant = tag.cpu_variant,
                digest = tag.digest,
                docker_client_config = tag.docker_client_config,
                cred_helpers = tag.cred_helpers,
                import_tags = tag.import_tags,
                os = tag.os,
                os_features = tag.os_features,
                os_version = tag.os_version,
                platform_features = tag.platform_features,
                puller_darwin = tag.puller_darwin,
                puller_linux_amd64 = tag.puller_linux_amd64,
                puller_linux_arm64 = tag.puller_linux_arm64,
                puller_linux_s390x = tag.puller_linux_s390x,
                registry = tag.registry,
                repository = tag.repository,
                tag = tag.tag,
                timeout = tag.timeout,
            )

container = module_extension(
    implementation = _impl,
    tag_classes = {
        "pull": _pull_tag,
    },
)
