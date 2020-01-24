# Copyright 2020 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""A rule for creating a kotlin container image.

The signature of kt_jvm_image is compatible with kt_jvm_binary.
"""

load("@io_bazel_rules_kotlin//kotlin:kotlin.bzl", "kt_jvm_binary", "kt_jvm_library")

load(
    "//java:image.bzl",
    "DEFAULT_JAVA_BASE",
    "jar_app_layer",
    "jar_dep_layer",
    _repositories = "repositories",
)

def kt_jvm_image(
        name,
        base = None,
        main_class = None,
        srcs = [],
        deps = [],
        layers = [],
        jvm_flags = [],
        **kwargs):
    """Builds a container image overlaying the kt_jvm_binary.

    Args:
        name: Name of the kt_jvm_image target.
        base: Base image to use for the kt_jvm_image.
        main_class: The main entrypoint class in the kotlin image.
        srcs: List of kotlin source files that will be used to build the binary
            to be included in the kt_jvm_image.
        deps: The dependencies of the kt_jvm_image target.
        jvm_flags: The flags to pass to the JVM when running the kotlin image.
        layers: Augments "deps" with dependencies that should be put into
            their own layers.
        **kwargs: See kt_jvm_binary.
    """
    binary_name = name + ".binary"

    # This is an inlined copy of kt_jvm_binary so that we properly collect
    # the JARs relevant to the kt_jvm_library.
    if srcs:
        kt_jvm_library(
            name = binary_name + "-lib",
            srcs = srcs,
            deps = deps + layers,
        )
        deps = deps + [binary_name + "-lib"]

    # This always belongs in a separate layer.
    # layers = layers + ["//external:kotlin"]

    kt_jvm_binary(
        name = binary_name,
        main_class = main_class,
        deps = deps + layers,
        srcs = srcs,
        **kwargs
    )

    index = 0
    base = base or DEFAULT_JAVA_BASE
    for dep in layers:
        this_name = "%s.%d" % (name, index)
        jar_dep_layer(name = this_name, base = base, dep = dep)
        base = this_name
        index += 1

    visibility = kwargs.get("visibility", None)
    tags = kwargs.get("tags", None)
    jar_app_layer(
        name = name,
        base = base,
        binary = binary_name,
        main_class = main_class,
        jvm_flags = jvm_flags,
        deps = deps,
        jar_layers = layers,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
        data = kwargs.get("data"),
        testonly = kwargs.get("testonly"),
    )

def repositories():
    _repositories()
