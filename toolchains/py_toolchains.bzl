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
"""Repo rule to register toolchains required for py_image and py3_image rules.
"""

load(
    "@bazel_tools//tools/cpp:lib_cc_configure.bzl",
    "get_cpu_value",
    "resolve_labels",
)
load("@bazel_tools//tools/osx:xcode_configure.bzl", "run_xcode_locator")

def _impl(repository_ctx):
    """Core implementation of _py_toolchains."""

    cpu_value = get_cpu_value(repository_ctx)
    env = repository_ctx.os.environ
    if "BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN" in env and env["BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN"] == "1":
        # Create an alias to the bazel_tools local toolchain as no cpp toolchain will be produced
        repository_ctx.file("BUILD", content = ("""# Alias to local toolchain
package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

alias(
    name = "container_cc_toolchain",
    actual = "@bazel_tools//tools/cpp:cc-toolchain-local",
)

"""), executable = False)

    else:
        if cpu_value == "x64_windows":
            # Note this is not well tested
            cpu_value = "x64_windows_msys"
        toolchain = "@local_config_cc//:cc-compiler-%s" % cpu_value
        if cpu_value == "darwin":
            # This needs to be carefully kept in sync with bazel/tools/cpp/cc_configure.bzl
            should_use_xcode = "BAZEL_USE_XCODE_TOOLCHAIN" in env and env["BAZEL_USE_XCODE_TOOLCHAIN"] == "1"
            xcode_toolchains = []
            paths = resolve_labels(repository_ctx, [
                "@bazel_tools//tools/osx:xcode_locator.m",
            ])
            if not should_use_xcode:
                (xcode_toolchains, _xcodeloc_err) = run_xcode_locator(
                    repository_ctx,
                    paths["@bazel_tools//tools/osx:xcode_locator.m"],
                )
            if should_use_xcode or xcode_toolchains:
                toolchain = "@local_config_cc//:cc-compiler-darwin_x86_64"
            else:
                toolchain = "@local_config_cc//:cc-compiler-darwin"

        repository_ctx.file("BUILD", content = ("""# Toolchain required for xx_image targets that rely on xx_binary
# which transitively require a C/C++ toolchain (currently only
# py_binary). This one is for local execution and will be required
# with versions of Bazel > 1.0.0
package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

load("@local_config_platform//:constraints.bzl", "HOST_CONSTRAINTS")

toolchain(
    name = "container_cc_toolchain",
    exec_compatible_with = HOST_CONSTRAINTS + ["@io_bazel_rules_docker//platforms:run_in_container"],
    target_compatible_with = HOST_CONSTRAINTS,
    toolchain = "%s",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
) 
""") % toolchain, executable = False)

py_toolchains = repository_rule(
    attrs = {},
    implementation = _impl,
)
