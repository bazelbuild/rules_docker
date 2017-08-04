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
"""A rule for creating a C++ Docker image.

The signature of this rule is compatible with cc_binary.
"""

load(
    "//docker/contrib/common:lang-image.bzl",
    "dep_layer",
    "app_layer",
)
load("//docker:pull.bzl", "docker_pull")

def repositories():
  excludes = native.existing_rules().keys()
  if "cc_image_base" not in excludes:
    docker_pull(
      name = "cc_image_base",
      registry = "gcr.io",
      repository = "distroless/cc",
      # 'latest' circa 2017-07-21
      digest = "sha256:942eb947818e7e32200950b600cc94d5477b03e0b99bf732b4c1e2bba6eec717",
    )

def cc_image(name, base=None, deps=[], layers=[], **kwargs):
  """Constructs a Docker image wrapping a cc_binary target.

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See cc_binary.
  """
  binary_name = name + ".binary"

  native.cc_binary(name=binary_name, deps=deps + layers, **kwargs)

  index = 0
  base = base or "@cc_image_base//image"
  for dep in layers:
    this_name = "%s.%d" % (name, index)
    dep_layer(name=this_name, base=base, dep=dep)
    base = this_name
    index += 1

  app_layer(name=name, base=base, binary=binary_name, layers=layers)
