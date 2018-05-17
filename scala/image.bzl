# Copyright 2017 Google Inc. All rights reserved.
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
"""A rule for creating a Scala container image.

The signature of scala_image is compatible with scala_binary.
"""

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_binary")
load("//container:container.bzl", "container_image")
load(
    "//java:image.bzl",
    "DEFAULT_JAVA_BASE",
    "jar_app_layer",
    "jar_dep_layer",
    _repositories = "repositories",
)

def scala_image(
        name,
        base = None,
        main_class = None,
        deps = [],
        runtime_deps = [],
        layers = [],
        jvm_flags = [],
        **kwargs):
    """Builds a container image overlaying the scala_binary.

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See scala_binary.
  """
    binary_name = name + ".binary"

    scala_binary(
        name = binary_name,
        main_class = main_class,
        # If the rule is turning a JAR built with java_library into
        # a binary, then it will appear in runtime_deps.  We are
        # not allowed to pass deps (even []) if there is no srcs
        # kwarg.
        deps = (deps + layers) or None,
        runtime_deps = runtime_deps,
        jvm_flags = jvm_flags,
        **kwargs
    )

    base = base or DEFAULT_JAVA_BASE
    for index, dep in enumerate(layers):
        this_name = "%s.%d" % (name, index)
        jar_dep_layer(name = this_name, base = base, dep = dep)
        base = this_name

    visibility = kwargs.get("visibility", None)
    tags = kwargs.get("tags", None)
    jar_app_layer(
        name = name,
        base = base,
        binary = binary_name,
        main_class = main_class,
        jvm_flags = jvm_flags,
        deps = deps,
        runtime_deps = runtime_deps,
        jar_layers = layers,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
    )

def repositories():
    _repositories()
