# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Definitions of language_tool_layer and toolchain_container rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")

# Providers must be imported with full path, including external repo name,
# otherwise we get errors with outputs of these rules.
load("@io_bazel_rules_docker//container:providers.bzl", "ImageInfo")
load("//container:container.bzl", _container = "container")
load("//docker/package_managers:apt_key.bzl", _key = "key")
load("//docker/package_managers:download_pkgs.bzl", _download = "download")
load("//docker/package_managers:install_pkgs.bzl", _install = "install")
load(":debian_pkg_tar.bzl", _generate_deb_tar = "generate")

LanguageToolLayerInfo = provider(fields = [
    "container_parts",
    "tars",
    "input_files",
    "env",
    "symlinks",
    "packages",
    "additional_repos",
    "keys",
    "installables_tar",
    "installation_cleanup_commands",
])

def _input_validation(kwargs):
    if "debs" in kwargs:
        fail("debs is not supported.")

    if "packages" in kwargs and "installables_tar" in kwargs:
        fail("'packages' and 'installables_tar' cannot be specified at the same time.")

    has_no_packages = "packages" not in kwargs or kwargs["packages"] == []
    if has_no_packages and "additional_repos" in kwargs:
        fail("'additional_repos' can only be specified when 'packages' is not empty.")
    if has_no_packages and "keys" in kwargs:
        fail("'keys' can only be specified when 'packages' is not empty.")

    has_no_tar = "installables_tar" not in kwargs or kwargs["installables_tar"] == ""
    has_no_layer = "language_layers" not in kwargs or kwargs["language_layers"] == []

    if has_no_packages and has_no_tar and has_no_layer and "installation_cleanup_commands" in kwargs:
        fail("'installation_cleanup_commands' can only be specified when at least " +
             "one of 'packages', 'installables_tar' or 'language_layers' " +
             "(if 'toolchain_container' rule) is not empty.")

def _language_tool_layer_impl(
        ctx,
        symlinks = None,
        env = None,
        tars = None,
        files = None,
        packages = None,
        additional_repos = None,
        keys = None,
        installables_tars = None,
        installation_cleanup_commands = ""):
    """Implementation for the language_tool_layer rule.

    Args:
      ctx: ctx of container_image rule
             (https://github.com/bazelbuild/rules_docker#container_image-1) +
           ctx of download_pkgs rule
             (https://github.com/GoogleCloudPlatform/base-images-docker/blob/master/package_managers/download_pkgs.bzl) +
           ctx of install_pkgs rule
             (https://github.com/GoogleCloudPlatform/base-images-docker/blob/master/package_managers/install_pkgs.bzl) +
           some overrides.
      symlinks: str Dict, overrides ctx.attr.symlinks
      env: str Dict, overrides ctx.attr.env
      tars: File list, overrides ctx.files.tars
      files: File list, overrides ctx.files.files
      packages: str List, overrides ctx.attr.packages
      additional_repos: str List, overrides ctx.attr.additional_repos
      keys: File list, overrides ctx.files.keys
      installables_tars: File list, overrides [ctx.file.installables_tar]
      installation_cleanup_commands: str, overrides ctx.attr.installation_cleanup_commands

    TODO(ngiraldo): add validations to restrict use of any other attrs.
    """

    symlinks = symlinks or ctx.attr.symlinks
    env = env or ctx.attr.env
    tars = tars or ctx.files.tars
    files = files or ctx.files.files
    packages = packages or ctx.attr.packages
    additional_repos = additional_repos or ctx.attr.additional_repos
    keys = keys or ctx.files.keys
    installables_tars = installables_tars or []
    installation_cleanup_commands = installation_cleanup_commands or ctx.attr.installation_cleanup_commands

    # If ctx.file.installables_tar is specified, ignore 'packages' and other tars in installables_tars.
    if ctx.file.installables_tar:
        installables_tars = [ctx.file.installables_tar]
        # Otherwise, download packages if packages list is not empty, and add the tar of downloaded
        # debs to installables_tars.

    elif packages:
        download_pkgs_output_tar = ctx.attr.name + "_output_tar.tar"
        download_pkgs_output_script = ctx.attr.name + "_script.sh"
        download_pkgs_output_metadata = ctx.attr.name + "_metadata.csv"

        aggregated_debian_tar = _generate_deb_tar.implementation(
            ctx,
            packages = packages,
            additional_repos = additional_repos,
            keys = keys,
            download_pkgs_output_tar = download_pkgs_output_tar,
            download_pkgs_output_script = download_pkgs_output_script,
            download_pkgs_output_metadata = download_pkgs_output_metadata,
        )

        installables_tars.append(aggregated_debian_tar[0].installables_tar)

    # Prepare new base image for the container_image rule.
    new_base = ctx.files.base[0]

    # Install debian packages in the base image.
    if installables_tars != []:
        # Create a list of paths of installables_tars.
        installables_tars_paths = []
        for tar in installables_tars:
            if tar:
                installables_tars_paths.append(tar.path)

        # Declare file for final tarball of debian packages to install.
        final_installables_tar = ctx.actions.declare_file(ctx.attr.name + "-packages.tar")

        # Combine all installables_tars into one tar. install_pkgs only takes a
        # single installables_tar as input.
        ctx.actions.run_shell(
            inputs = installables_tars,
            outputs = [final_installables_tar],
            command = "tar cvf {output_tar} --files-from /dev/null && \
        for i in {input_tars}; do tar A --file={output_tar} $i; done".format(
                output_tar = final_installables_tar.path,
                input_tars = " ".join(installables_tars_paths),
            ),
        )

        # Declare intermediate output file generated by install_pkgs rule.
        install_pkgs_out = ctx.actions.declare_file(ctx.attr.name + "-with-packages.tar")

        # install_pkgs rule consumes 'final_installables_tar' and 'installation_cleanup_commands'.
        _install.implementation(
            ctx,
            image_tar = ctx.files.base[0],
            installables_tar = final_installables_tar,
            installation_cleanup_commands = installation_cleanup_commands,
            output_image_name = ctx.attr.name + "-with-packages",
            output_tar = install_pkgs_out,
        )

        # Set the image with packages installed to be the new base.
        new_base = install_pkgs_out

    # Install tars and configure env, symlinks using the container_image rule.
    result = _container.image.implementation(
        ctx,
        base = new_base,
        symlinks = symlinks,
        output_executable = ctx.outputs.build_script,
        env = env,
        tars = tars,
        files = files,
    )

    if hasattr(result[1], "runfiles"):
        result_runfiles = result[1].runfiles
    else:
        result_runfiles = result[1].default_runfiles

    return [
        DefaultInfo(
            executable = ctx.outputs.build_script,
            files = result[1].files,
            runfiles = result_runfiles,
        ),
        LanguageToolLayerInfo(
            container_parts = result[0].container_parts,
            tars = tars,
            input_files = files,
            env = env,
            symlinks = symlinks,
            packages = packages,
            additional_repos = additional_repos,
            keys = keys,
            installables_tar = ctx.file.installables_tar,
            installation_cleanup_commands = installation_cleanup_commands,
        ),
        ImageInfo(
            container_parts = result[0].container_parts,
            legacy_run_behavior = result[0].legacy_run_behavior,
            docker_run_flags = result[0].docker_run_flags,
        ),
    ]

language_tool_layer_attrs = dicts.add(_container.image.attrs, _key.attrs, _download.attrs, _install.attrs, {
    "image": attr.label(
        allow_single_file = True,
        doc = "Redeclared to be non-mandatory, do not set.",
    ),
    "image_tar": attr.label(
        allow_single_file = True,
        doc = "Redeclared to be non-mandatory, do not set.",
    ),
    "installables_tar": attr.label(
        allow_single_file = True,
        doc = "Redeclared to be non-mandatory, do not set.",
    ),
    "keys": attr.label_list(
        allow_files = True,
        doc = "Redeclared to be non-mandatory, do not set.",
    ),
    "output_image_name": attr.string(
        doc = "Redeclared to be non-mandatory, do not set.",
    ),
    "packages": attr.string_list(
        doc = "List of debian packages installed by the layer.",
    ),
})

language_tool_layer_ = rule(
    attrs = language_tool_layer_attrs,
    doc = ("Rule to create a container layer that installs a set of debian " +
           "packages. A wrapper around attrs in container_image, " +
           "download_pkgs and install_pkgs rules."),
    executable = True,
    outputs = _container.image.outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _language_tool_layer_impl,
)

def language_tool_layer(**kwargs):
    """A wrapper around attrs in container_image, download_pkgs and install_pkgs rules.

    Downloads and installs debian packages using
    https://github.com/GoogleCloudPlatform/base-images-docker/tree/master/package_managers,
    and configures the rest using https://github.com/bazelbuild/rules_docker#container_image-1.

    Args:
      **kwargs: Same args as https://github.com/bazelbuild/rules_docker#container_image-1
            minus:
                debs: debian packages should be listed in 'packages', or be included in
                'installables_tar' as .deb files.
            plus:
                packages: list of packages to fetch and install in the base image.
                additional_repos: list of additional debian package repos to use,
                in sources.list format.
                keys: list of labels of additional gpg keys to use while downloading
                packages.
                installables_tar: a tar of debian packages to install in the base image.
                installation_cleanup_commands: cleanup commands to run after package
                installation.
    """

    _input_validation(kwargs)

    language_tool_layer_(**kwargs)

def _toolchain_container_impl(ctx):
    """Implementation for the toolchain_container rule.

    toolchain_container rule composes all attrs from itself and language_tool_layer(s),
    and generates container using container_image rule.

    'additional_repos' can only be specified when 'packages' is speficified.
    'installation_cleanup_commands' can only be specified when at least one of
    'packages' or 'installables_tar' is specified.

    Args:
      ctx: ctx as the same as for container_image + list of language_tool_layer(s)
           https://github.com/bazelbuild/rules_docker#container_image
    """

    tars = []
    files = []
    env = {}
    symlinks = {}
    packages = []
    additional_repos = []
    keys = []
    installables_tars = []
    installation_cleanup_commands = "cd ."

    # TODO(ngiraldo): we rewrite env and symlinks if there are conficts,
    # warn the user of conflicts or error out.
    for layer in ctx.attr.language_layers:
        tars.extend(layer[LanguageToolLayerInfo].tars)
        files.extend(layer[LanguageToolLayerInfo].input_files)
        env.update(layer[LanguageToolLayerInfo].env)
        symlinks.update(layer[LanguageToolLayerInfo].symlinks)
        packages.extend(layer[LanguageToolLayerInfo].packages)
        additional_repos.extend(layer[LanguageToolLayerInfo].additional_repos)
        keys.extend(layer[LanguageToolLayerInfo].keys)
        if layer[LanguageToolLayerInfo].installables_tar:
            installables_tars.append(layer[LanguageToolLayerInfo].installables_tar)
        if layer[LanguageToolLayerInfo].installation_cleanup_commands:
            installation_cleanup_commands += (" && " + layer[LanguageToolLayerInfo].installation_cleanup_commands)
    tars += ctx.files.tars
    env.update(ctx.attr.env)
    symlinks.update(ctx.attr.symlinks)
    packages = depset(direct = ctx.attr.packages + packages)
    additional_repos = depset(direct = ctx.attr.additional_repos + additional_repos)
    keys = depset(direct = ctx.files.keys + keys)
    if ctx.attr.installation_cleanup_commands:
        installation_cleanup_commands += (" && " + ctx.attr.installation_cleanup_commands)

    return _language_tool_layer_impl(
        ctx,
        symlinks = symlinks,
        env = env,
        tars = tars,
        files = files,
        packages = packages,
        additional_repos = additional_repos,
        keys = keys,
        installables_tars = installables_tars,
        installation_cleanup_commands = installation_cleanup_commands,
    )

toolchain_container_ = rule(
    attrs = dicts.add(
        language_tool_layer_attrs,
        {
            "language_layers": attr.label_list(
                doc = "List of language_tool_layer targets to add to this language_tool_layer",
                allow_rules = ["language_tool_layer_"],
            ),
        },
    ),
    doc = ("toolchain_container_ rule composes all attrs from itself and " +
           "language_tool_layer(s), and generates container using " +
           "container_image rule."),
    executable = True,
    outputs = _container.image.outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _toolchain_container_impl,
)

def toolchain_container(**kwargs):
    """Composes multiple language_tool_layers into a single resulting image.

    A toolchain_container is a container_image composed from multiple language_tool_layer
    targets. Each language_tool_layer target can install a list of debian packages.

    If 'installables_tar' is specified in the 'toolchain_container' rule, then
    'packages' or 'installables_tar' specified in any of the 'language_layers'
    passed to this 'toolchain_container' rule will be ignored.

    Args:
      **kwargs: Same args as https://github.com/bazelbuild/rules_docker#container_image-1
            minus:
                debs: debian packages should be listed in 'packages', or be included in
                    'installables_tar' as .deb files.
            plus:
                language_layers: a list of language_tool_layer.
                installables_tar: a tar of debian packages to install in the base image.
                packages: list of packages to fetch and install in the base image.
                additional_repos: list of additional debian package repos to use,
                in sources.list format.
                keys: list of labels of additional gpg keys to use while downloading
                packages.
                installation_cleanup_commands: cleanup commands to run after package
                installation.
    """

    _input_validation(kwargs)

    toolchain_container_(**kwargs)
