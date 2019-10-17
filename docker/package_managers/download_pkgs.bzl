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

"""Rule for downloading apt packages and tar them in a .tar file."""

def _generate_add_additional_repo_commands(ctx, additional_repos):
    return """printf "{repos}" >> /etc/apt/sources.list.d/{name}_repos.list""".format(
        name = ctx.attr.name,
        repos = "\n".join(additional_repos.to_list()),
    )

def _generate_download_commands(ctx, packages, additional_repos):
    return """#!/bin/bash
set -ex
{add_additional_repo_commands}
# Remove /var/lib/apt/lists/* in the base image. apt-get update -y command will create them.
rm -rf /var/lib/apt/lists/*
# Fetch Index
apt-get update -y
# Make partial dir
mkdir -p /tmp/install/./partial
# Install command
apt-get install --no-install-recommends -y -q -o Dir::Cache="/tmp/install" -o Dir::Cache::archives="." {packages} --download-only

items=$(ls /tmp/install/*.deb)
if [ $items = ""]; then
    echo "Did not find the .deb files for debian packages {packages} in /tmp/install. Did apt-get actually succeed?" && false
fi
# Generate csv listing the name & versions of the debian packages.
# Example contents of a metadata CSV with debian packages gcc 8.1 & clang 9.1:
# Name,Version
# gcc,7.1
# clang,9.1
echo "Generating metadata CSV file {installables}_metadata.csv"
echo Name,Version > {installables}_metadata.csv
dpkg_deb_path=$(which dpkg-deb)
for item in $items; do
    echo "Adding information about $item to metadata CSV"
    pkg_name=$($dpkg_deb_path -f $item Package)
    if [ $pkg_name = ""]; then
        echo "Failed to get name of the package for $item" && false
    fi
    pkg_version=$($dpkg_deb_path -f $item Version)
    if [ $pkg_version = ""]; then
        echo "Failed to get the version of the package for $item" && false
    fi
    echo "Package $pkg_name, Version $pkg_version"
    echo -n "$pkg_name," >> {installables}_metadata.csv
    echo $pkg_version >> {installables}_metadata.csv
done;
# Tar command to only include all the *.deb files and ignore other directories placed in the cache dir.
tar -cpf {installables}_packages.tar --mtime='1970-01-01' --directory /tmp/install/. `cd /tmp/install/. && ls *.deb`""".format(
        installables = ctx.attr.name,
        packages = " ".join(packages.to_list()),
        add_additional_repo_commands = _generate_add_additional_repo_commands(ctx, additional_repos),
    )

def _impl(ctx, image_tar = None, packages = None, additional_repos = None, output_executable = None, output_tar = None, output_script = None, output_metadata = None):
    """Implementation for the download_pkgs rule.

    Args:
        ctx: The bazel rule context
        image_tar: File, overrides ctx.file.image_tar
        packages: str List, overrides ctx.attr.packages
        additional_repos: str List, overrides ctx.attr.additional_repos
        output_executable: File, overrides ctx.outputs.executable
        output_tar: File, overrides ctx.outputs.pkg_tar
        output_script: File, overrides ctx.outputs.build_script
        output_metadata: File, overrides ctx.outputs.metadata_csv
    """
    image_tar = image_tar or ctx.file.image_tar
    packages = depset(packages or ctx.attr.packages)
    additional_repos = depset(additional_repos or ctx.attr.additional_repos)
    output_executable = output_executable or ctx.outputs.executable
    output_tar = output_tar or ctx.outputs.pkg_tar
    output_script = output_script or ctx.outputs.build_script
    output_metadata = output_metadata or ctx.outputs.metadata_csv

    if not packages:
        fail("attribute 'packages' given to download_pkgs rule by {} was empty.".format(attr.label))

    toolchain_info = ctx.toolchains["@io_bazel_rules_docker//toolchains/docker:toolchain_type"].info

    # Generate a shell script to execute the apt_get inside this docker image.
    # We use full paths here.
    ctx.actions.expand_template(
        template = ctx.file._run_download_tpl,
        output = output_script,
        substitutions = {
            "%{docker_tool_path}": toolchain_info.tool_path,
            "%{download_commands}": _generate_download_commands(ctx, packages, additional_repos),
            "%{image_id_extractor_path}": ctx.executable._extract_image_id.path,
            "%{image_tar}": image_tar.path,
            "%{installables}": ctx.attr.name,
            "%{output_metadata}": output_metadata.path,
            "%{output}": output_tar.path,
        },
        is_executable = True,
    )

    ctx.actions.run(
        outputs = [output_tar, output_metadata],
        executable = output_script,
        inputs = [image_tar],
        tools = [ctx.executable._extract_image_id],
        use_default_shell_env = True,
    )

    # Generate a very similar one as output executable, but with short paths
    # This is because the paths for running within bazel build are different.
    ctx.actions.expand_template(
        template = ctx.file._run_download_tpl,
        output = output_executable,
        substitutions = {
            "%{docker_tool_path}": toolchain_info.tool_path,
            "%{download_commands}": _generate_download_commands(ctx, packages, additional_repos),
            "%{image_id_extractor_path}": "./" + ctx.executable._extract_image_id.short_path,
            "%{image_tar}": image_tar.short_path,
            "%{installables}": ctx.attr.name,
            "%{output_metadata}": output_metadata.short_path,
            "%{output}": output_tar.short_path,
        },
        is_executable = True,
    )

    return struct(
        runfiles = ctx.runfiles(
            files = [
                image_tar,
                output_script,
                output_metadata,
                ctx.executable._extract_image_id,
            ],
            transitive_files = ctx.attr._extract_image_id.files,
        ),
        files = depset([output_executable]),
    )

_attrs = {
    "additional_repos": attr.string_list(
        doc = ("list of additional debian package repos to use, in " +
               "sources.list format"),
    ),
    "image_tar": attr.label(
        doc = "The image tar for the container used to download packages.",
        allow_single_file = True,
        mandatory = True,
    ),
    "packages": attr.string_list(
        doc = "list of packages to download. e.g. ['curl', 'netbase']",
        mandatory = True,
    ),
    "_extract_image_id": attr.label(
        default = Label("//contrib:extract_image_id"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "_run_download_tpl": attr.label(
        default = Label("//docker/package_managers:run_download.sh.tpl"),
        allow_single_file = True,
    ),
}

_outputs = {
    "build_script": "%{name}.sh",
    "metadata_csv": "%{name}_metadata.csv",
    "pkg_tar": "%{name}.tar",
}

# Export download_pkgs rule for other bazel rules to depend on.
download = struct(
    attrs = _attrs,
    outputs = _outputs,
    implementation = _impl,
)

download_pkgs = rule(
    attrs = _attrs,
    doc = ("This rule creates a script to download packages " +
           "within a container. The script bunldes all the " +
           "packages in a tarball."),
    executable = True,
    outputs = _outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _impl,
)
