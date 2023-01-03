"""Docker toolchain bzlmod extensions.
"""

load("//toolchains/docker:toolchain.bzl", "configure_attrs", "toolchain_configure")

_attrs = {
    "name": attr.string(
        mandatory = True,
        doc = "The name of the repo.",
    ),
}
_attrs.update(**configure_attrs)

_configure_tag = tag_class(
    attrs = _attrs,
    doc = "configure docker toolchain",
)

def _impl(ctx):
    for mod in ctx.modules:
        for tag in mod.tags.configure:
            toolchain_configure(
                name = tag.name,
                build_tar_target = tag.build_tar_target,
                client_config = tag.client_config,
                cred_helpers = tag.cred_helpers,
                docker_flags = tag.docker_flags,
                docker_path = tag.docker_path,
                docker_target = tag.docker_target,
                gzip_path = tag.gzip_path,
                gzip_target = tag.gzip_target,
                xz_path = tag.xz_path,
                xz_target = tag.xz_target,
            )

docker_toolchain = module_extension(
    implementation = _impl,
    tag_classes = {
        "configure": _configure_tag,
    },
)
