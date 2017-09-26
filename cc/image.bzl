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
    "dep_layer",
    "app_layer",
)
load(
    "//container:container.bzl",
    "container_pull",
    _repositories = "repositories",
)

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
      # 'latest' circa 2017-09-15
      digest = "sha256:84d70ebb1baee21424894a23e90f4c40c6f7f7ec747396525b57e4ae432edaeb",
    )

def cc_image(name, base=None, deps=[], layers=[], **kwargs):
  """Constructs a container image wrapping a cc_binary target.

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See cc_binary.
  """
  binary_name = name + ".binary"

  if layers:
    print("cc_image does not benefit from layers=[], got: %s" % layers)

  native.cc_binary(name=binary_name, deps=deps + layers, **kwargs)

  index = 0
  base = base or "@cc_image_base//image"
  for dep in layers:
    this_name = "%s.%d" % (name, index)
    dep_layer(name=this_name, base=base, dep=dep)
    base = this_name
    index += 1

  app_layer(name=name, base=base, binary=binary_name, layers=layers)
