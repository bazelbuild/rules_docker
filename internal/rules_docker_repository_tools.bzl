# Copyright 2019 The Bazel Authors. All rights reserved.
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

load("//internal:execution.bzl", "env_execute", "executable_extension")
load("@bazel_gazelle//internal:go_repository_cache.bzl", "read_cache_env")

_RULES_DOCKER_TOOLS_BUILD_FILE = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "puller",
    srcs = ["bin/puller{extension}"],
)

exports_files(["ROOT"])
"""

def _rules_docker_repository_tools_impl(ctx):
    # Create a link to the rules_docker repo. This will be our GOPATH.
    env = read_cache_env(ctx, str(ctx.path(ctx.attr.go_cache)))
    extension = executable_extension(ctx)
    go_tool = env["GOROOT"] + "/bin/go" + extension

    ctx.symlink(
        ctx.path(Label("@io_bazel_rules_docker//:WORKSPACE")).dirname,
        "src/github.com/bazelbuild/rules_docker",
    )

    env.update({
        "GOPATH": str(ctx.path(".")),
        "GO111MODULE": "off",
        # workaround: avoid the Go SDK paths from leaking into the binary
        "GOROOT_FINAL": "GOROOT",
        # workaround: avoid cgo paths in /tmp leaking into binary
        "CGO_ENABLED": "0",
    })

    if "PATH" in ctx.os.environ:
        # workaround: to find gcc for go link tool on Arm platform
        env["PATH"] = ctx.os.environ["PATH"]
    if "GOPROXY" in ctx.os.environ:
        env["GOPROXY"] = ctx.os.environ["GOPROXY"]

    # Build the tools.
    args = [
        go_tool,
        "install",
        "-ldflags",
        "-w -s",
        "-gcflags",
        "all=-trimpath=" + env["GOPATH"],
        "-asmflags",
        "all=-trimpath=" + env["GOPATH"],
        "github.com/bazelbuild/rules_docker/container/go/cmd/puller",
    ]
    result = env_execute(ctx, args, environment = env)
    if result.return_code:
        fail("failed to build tools: " + result.stderr)

    # add a build file to export the tools
    ctx.file(
        "BUILD.bazel",
        _RULES_DOCKER_TOOLS_BUILD_FILE.format(extension = executable_extension(ctx)),
        False,
    )
    ctx.file(
        "ROOT",
        "",
        False,
    )

rules_docker_repository_tools = repository_rule(
    _rules_docker_repository_tools_impl,
    attrs = {
        "go_cache": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
    },
    environ = [
        "GOCACHE",
        "GOPATH",
    ],
)
