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
"container_load rule"

load("//internal:execution.bzl", "env_execute", "executable_extension")

_DOC = """A repository rule that examines the contents of a docker save tarball and creates a container_import target.

This extracts the tarball amd creates a filegroup of the untarred objects in OCI intermediate layout.
The created target can be referenced as `@label_name//image`.
"""

def _impl(repository_ctx):
    """Core implementation of container_load."""

    # Add an empty top-level BUILD file.
    repository_ctx.file("BUILD", "")

    repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])
load("@io_bazel_rules_docker//container:import.bzl", "container_import")

container_import(
    name = "image",
    config = "config.json",
    layers = glob(["*.tar.gz"]),
)""")

    loader_args = [
        "-directory",
        repository_ctx.path("image"),
        "-tarball",
        repository_ctx.path(repository_ctx.attr.file),
    ]

    if repository_ctx.attr.use_precompiled_binaries:
        loader = repository_ctx.attr._loader_linux_amd64
        if repository_ctx.os.name.lower().startswith("mac os"):
            loader = repository_ctx.attr._loader_darwin
        elif repository_ctx.os.name.lower().startswith("linux"):
            arch = repository_ctx.execute(["uname", "-m"]).stdout.strip()
            if arch == "arm64" or arch == "aarch64":
                loader = repository_ctx.attr._loader_linux_arm64
            elif arch == "s390x":
                loader = repository_ctx.attr._loader_linux_s390x
        loader_path = repository_ctx.path(loader)
        result = repository_ctx.execute([loader_path] + loader_args)
    else:
        loader_path = str(repository_ctx.path(Label("@rules_docker_repository_tools//:bin/loader{}".format(executable_extension(repository_ctx)))))
        result = env_execute(repository_ctx, [loader_path] + loader_args)

    if result.return_code:
        fail("Importing from tarball failed (status %s): %s" % (result.return_code, result.stderr))

container_load = repository_rule(
    doc = _DOC,
    attrs = {
        "file": attr.label(
            doc = """A label targeting a single file which is a compressed or uncompressed tar,
            as obtained through `docker save IMAGE`.""",
            allow_single_file = True,
            mandatory = True,
        ),
        "_loader_darwin": attr.label(
            executable = True,
            default = Label("@loader_darwin//file:downloaded"),
            cfg = "exec",
        ),
        "_loader_linux_amd64": attr.label(
            executable = True,
            default = Label("@loader_linux_amd64//file:downloaded"),
            cfg = "exec",
        ),
        "_loader_linux_arm64": attr.label(
            executable = True,
            default = Label("@loader_linux_arm64//file:downloaded"),
            cfg = "exec",
        ),
        "_loader_linux_s390x": attr.label(
            executable = True,
            default = Label("@loader_linux_s390x//file:downloaded"),
            cfg = "exec",
        ),
        "use_precompiled_binaries": attr.bool(
            doc = """Whether to use precompiled binaries.
            If true, the loader will be fetched from a prebuilt binary (legacy).
            If false, loader will be built from source.""",
            default = True,
        ),
    },
    implementation = _impl,
)
