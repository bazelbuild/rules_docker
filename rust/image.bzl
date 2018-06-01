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

load(
    "//lang:image.bzl",
    "app_layer",
    "dep_layer",
)
load(
    "//cc:image.bzl",
    "DEFAULT_BASE",
    _repositories = "repositories",
)
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")

def repositories():
    _repositories()

def rust_image(name, base = None, deps = [], layers = [], binary = None, **kwargs):
    """Constructs a container image wrapping a rust_binary target.

  Args:
    binary: An alternative binary target to use instead of generating one.
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See rust_binary.
  """
    if layers:
        print("rust_image does not benefit from layers=[], got: %s" % layers)

    if not binary:
        binary = name + "_binary"
        rust_binary(name = binary, deps = deps + layers, **kwargs)
    elif deps:
        fail("kwarg does nothing when binary is specified", "deps")

    base = base or DEFAULT_BASE
    for index, dep in enumerate(layers):
        this_name = "%s_%d" % (name, index)
        dep_layer(name = this_name, base = base, dep = dep)
        base = this_name

    visibility = kwargs.get("visibility", None)
    tags = kwargs.get("tags", None)
    app_layer(
        name = name,
        base = base,
        binary = binary,
        lang_layers = layers,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
    )
