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
"""A rule for creating a C++ container image.

The signature of this rule is compatible with cc_binary.
"""

load(
    "//lang:image.bzl",
    "app_layer",
)
load(
    "//repositories:repositories.bzl",
    _repositories = "repositories",
)
load(
    "//container:container.bzl",
    "container_pull",
)

# Load the resolved digests.
load(":cc.bzl", "DIGESTS")

def repositories():
    # Call the core "repositories" function to reduce boilerplate.
    # This is idempotent if folks call it themselves.
    _repositories()

    excludes = native.existing_rules().keys()
    if "cc_image_base" not in excludes:
        container_pull(
            name = "cc_image_base",
            registry = "gcr.io",
            repository = "distroless/cc",
            digest = DIGESTS["latest"],
        )
    if "cc_debug_image_base" not in excludes:
        container_pull(
            name = "cc_debug_image_base",
            registry = "gcr.io",
            repository = "distroless/cc",
            digest = DIGESTS["debug"],
        )

DEFAULT_BASE = select({
    "@io_bazel_rules_docker//:fastbuild": "@cc_image_base//image",
    "@io_bazel_rules_docker//:debug": "@cc_debug_image_base//image",
    "@io_bazel_rules_docker//:optimized": "@cc_image_base//image",
    "//conditions:default": "@cc_image_base//image",
})

def cc_image(name, base = None, deps = [], layers = [], binary = None, **kwargs):
    """Constructs a container image wrapping a cc_binary target.

  Args:
    binary: An alternative binary target to use instead of generating one.
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See cc_binary.
  """
    if layers:
        print("cc_image does not benefit from layers=[], got: %s" % layers)

    if not binary:
        binary = name + ".binary"
        native.cc_binary(name = binary, deps = deps + layers, **kwargs)
    elif deps:
        fail("kwarg does nothing when binary is specified", "deps")

    base = base or DEFAULT_BASE
    for index, dep in enumerate(layers):
        base = app_layer(name = "%s.%d" % (name, index), base = base, dep = dep)
        base = app_layer(name = "%s.%d-symlinks" % (name, index), base = base, dep = dep, binary = binary)

    visibility = kwargs.get("visibility", None)
    tags = kwargs.get("tags", None)
    app_layer(
        name = name,
        base = base,
        binary = binary,
        visibility = visibility,
        tags = tags,
        args = kwargs.get("args"),
        data = kwargs.get("data"),
    )
