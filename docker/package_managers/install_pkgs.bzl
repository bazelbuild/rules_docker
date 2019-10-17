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

"""Rule for installing apt packages from a tar file into a docker image.

In addition to the base install_pkgs rule, we expose its constituents
(attr, outputs, implementation) directly so that others can use them
in their rules' implementation. The expectation in such cases is that
users will write something like:

  load(
    "@io_bazel_rules_docker//docker/package_managers:install_pkgs.bzl",
    _install = "install",
  )

  def _impl(ctx):
    ...
    return _install.implementation(ctx, ... kwarg overrides ...)

  _my_rule = rule(
      attrs = _install.attrs + {
         # My attributes, or overrides of _install.attrs defaults.
         ...
      },
      outputs = _install.outputs,
      implementation = _impl,
  )

"""

def _generate_install_commands(tar, installation_cleanup_commands):
    return """
tar -xvf {tar}
dpkg -i --force-depends ./*.deb
dpkg --configure -a
apt-get install -f
{installation_cleanup_commands}
# delete the files that vary build to build
rm -f /var/log/dpkg.log
rm -f /var/log/alternatives.log
rm -f /var/cache/ldconfig/aux-cache
rm -f /var/cache/apt/pkgcache.bin
mkdir -p /run/mount/ && touch /run/mount/utab""".format(tar = tar, installation_cleanup_commands = installation_cleanup_commands)

def _impl(ctx, image_tar = None, installables_tar = None, installation_cleanup_commands = "", output_image_name = "", output_tar = None):
    """Implementation for the install_pkgs rule.

    Args:
      ctx: The bazel rule context
      image_tar: File, overrides ctx.file.image_tar
      installables_tar: File, overrides ctx.file.installables_tar
      installation_cleanup_commands: str, overrides ctx.attr.installation_cleanup_commands
      output_image_name: str, overrides ctx.attr.output_image_name
      output_tar: File, overrides ctx.outputs.out
    """
    image_tar = image_tar or ctx.file.image_tar
    installables_tar = installables_tar or ctx.file.installables_tar
    installation_cleanup_commands = installation_cleanup_commands or ctx.attr.installation_cleanup_commands
    output_image_name = output_image_name or ctx.attr.output_image_name
    output_tar = output_tar or ctx.outputs.out

    installables_tar_path = installables_tar.path

    # Generate the installer.sh script
    install_script = ctx.actions.declare_file("%s.install" % (ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._installer_tpl,
        substitutions = {
            "%{install_commands}": _generate_install_commands(installables_tar_path, installation_cleanup_commands),
            "%{installables_tar}": installables_tar_path,
        },
        output = install_script,
        is_executable = True,
    )
    unstripped_tar = ctx.actions.declare_file(output_tar.basename + ".unstripped")

    script = ctx.actions.declare_file(ctx.label.name + ".build")

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    ctx.actions.expand_template(
        template = ctx.file._run_install_tpl,
        output = script,
        substitutions = {
            "%{base_image_tar}": image_tar.path,
            "%{docker_tool_path}": toolchain_info.tool_path,
            "%{image_id_extractor_path}": ctx.executable._extract_image_id.path,
            "%{installables_tar}": installables_tar_path,
            "%{installer_script}": install_script.path,
            "%{output_file_name}": unstripped_tar.path,
            "%{output_image_name}": output_image_name,
            "%{to_json_tool}": ctx.executable._to_json_tool.path,
            "%{util_script}": ctx.file._image_utils.path,
        },
        is_executable = True,
    )

    ctx.actions.run(
        outputs = [unstripped_tar],
        inputs = [
            image_tar,
            install_script,
            installables_tar,
            ctx.file._image_utils,
        ],
        tools = [ctx.executable._extract_image_id, ctx.executable._to_json_tool],
        executable = script,
        use_default_shell_env = True,
    )
    args = ctx.actions.args()
    args.add(unstripped_tar, format = "--in_tar_path=%s")
    args.add(output_tar, format = "--out_tar_path=%s")
    ctx.actions.run(
        outputs = [output_tar],
        inputs = [unstripped_tar],
        executable = ctx.executable._config_stripper,
        arguments = [args],
        use_default_shell_env = True,
    )

    return struct()

_attrs = {
    "image_tar": attr.label(
        allow_single_file = True,
        doc = "The image tar for the container used to install packages.",
        mandatory = True,
    ),
    "installables_tar": attr.label(
        allow_single_file = [".tar"],
        doc = ("Tar with deb installables, should be a tar produced by a " +
               " download_pkgs rule."),
        mandatory = True,
    ),
    "installation_cleanup_commands": attr.string(
        doc = ("Commands to run after installation, to e.g., remove or " +
               "otherwise modify files created during installation."),
        default = "",
    ),
    "output_image_name": attr.string(
        doc = ("Name of container_image produced with the packages installed."),
        mandatory = True,
    ),
    "_config_stripper": attr.label(
        default = "//docker/util:config_stripper",
        executable = True,
        cfg = "host",
    ),
    "_extract_image_id": attr.label(
        default = Label("//contrib:extract_image_id"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "_image_utils": attr.label(
        default = "//docker/util:image_util.sh",
        allow_single_file = True,
    ),
    "_installer_tpl": attr.label(
        default = Label("//docker/package_managers:installer.sh.tpl"),
        allow_single_file = True,
    ),
    "_run_install_tpl": attr.label(
        default = Label("//docker/package_managers:run_install.sh.tpl"),
        allow_single_file = True,
    ),
    "_to_json_tool": attr.label(
        default = Label("//docker/util:to_json"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}

_outputs = {
    "out": "%{name}.tar",
}

# Export install_pkgs rule for other bazel rules to depend on.
install = struct(
    attrs = _attrs,
    outputs = _outputs,
    implementation = _impl,
)

install_pkgs = rule(
    attrs = _attrs,
    doc = ("This rule install deb packages, obtained via " +
           "a download_pkgs rule, within a container. "),
    outputs = _outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _impl,
)
