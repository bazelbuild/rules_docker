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
"""A rule for creating a Rust container image.

The signature of this rule is compatible with rust_binary.
"""

load("@rules_rust//rust:defs.bzl", "rust_binary")
load(
    "//cc:image.bzl",
    "DEFAULT_BASE",
    _repositories = "repositories",
)
load(
    "//lang:image.bzl",
    "app_layer",
)

def repositories():
    """Import the dependencies for the rule_image rule.
    """
    _repositories()

def rust_image(name, base = None, deps = [], layers = [], env = {}, binary = None, **kwargs):
    """Constructs a container image wrapping a rust_binary target.

  Args:
    name: Name of the rust_image target.
    base: Base image to use for the rust_image.
    deps: Dependencies of the rust_image target.
    layers: Augments "deps" with dependencies that should be put into their own layers.
    env: Environment variables for the rust_image.
    binary: An alternative binary target to use instead of generating one.
    **kwargs: See rust_binary.
  """
    if layers:
        # buildifier: disable=print
        print("rust_image does not benefit from layers=[], got: %s" % layers)

    if not binary:
        binary = name + "_binary"
        rust_binary(name = binary, deps = deps + layers, **kwargs)
    elif deps:
        fail("kwarg does nothing when binary is specified", "deps")

    base = base or DEFAULT_BASE
    tags = kwargs.get("tags", None)
    for index, dep in enumerate(layers):
        base = app_layer(name = "%s_%d" % (name, index), base = base, dep = dep, tags = tags)
        base = app_layer(name = "%s_%d-symlinks" % (name, index), base = base, dep = dep, binary = binary, tags = tags)

    visibility = kwargs.get("visibility", None)
    app_layer(
        name = name,
        base = base,
        env = env,
        binary = binary,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
        data = kwargs.get("data"),
        testonly = kwargs.get("testonly"),
    )
