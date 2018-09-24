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
"""Repository rule to create a javabase to use with rules_docker."""

def auto_configure_fail(msg):
    """Output failure message when auto configuration fails."""
    red = "\033[0;31m"
    no_color = "\033[0m"
    fail("\n%sAuto-Configuration Error:%s %s\n" % (red, no_color, msg))

def _find_java_home(repository_ctx):
    env_value = repository_ctx.os.environ.get("JAVA_HOME")
    if env_value != None:
        return env_value
    auto_configure_fail("Cannot find java or JAVA_HOME; please set the" +
                        " JAVA_HOME environment variable")

_BUILD = """
package(default_visibility = ["//visibility:public"])

java_runtime(
    name = "jdk",
    srcs = [],
    java_home = "{}",
)
"""

_DEFAULT_BUILD = """
package(default_visibility = ["//visibility:public"])

alias(
    name = "jdk",
    actual = "@local_jdk//:jdk"
)
"""

def java_autoconf_impl(repository_ctx):
    env = repository_ctx.os.environ
    if "EXPERIMENTAL_TRANSITIVE_JAVA_DEPS" in env and env["EXPERIMENTAL_TRANSITIVE_JAVA_DEPS"] == "1":
        java_home = _find_java_home(repository_ctx)
        repository_ctx.file("BUILD", _BUILD.format(java_home))
    else:
        repository_ctx.file("BUILD", _DEFAULT_BUILD)

java_autoconf = repository_rule(
    environ = [
        "EXPERIMENTAL_TRANSITIVE_JAVA_DEPS",
        "JAVA_HOME",
    ],
    implementation = java_autoconf_impl,
)

def java_configure():
    """A Java configuration rule that generates a target to be used as javabase.

    This rule, by default, creates an alias that points to @local_jdk.
    If EXPERIMENTAL_TRANSITIVE_JAVA_DEPS=1 is set in the environment, this
    rule creates a java_runtime target with a java_home pointing to the
    JAVA_HOME.
    """
    java_autoconf(name = "local_config_java")
