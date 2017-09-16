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
"""A rule for creating a Python Docker image.

The signature of this rule is compatible with py_binary.
"""

load(
    "//docker/contrib/common:lang-image.bzl",
    "dep_layer",
    "app_layer",
)
load("//docker:pull.bzl", "docker_pull")

def repositories():
  excludes = native.existing_rules().keys()
  if "py_image_base" not in excludes:
    docker_pull(
      name = "py_image_base",
      registry = "gcr.io",
      repository = "distroless/python2.7",
      # 'latest' circa 2017-09-15
      digest = "sha256:61477696140326e1192dc6ce1a5f8dfe7e99591dbd7934f19141b4a303023600",
    )

def py_image(name, base=None, deps=[], layers=[], **kwargs):
  """Constructs a Docker image wrapping a py_binary target.

  Args:
    layers: Augments "deps" with dependencies that should be put into
           their own layers.
    **kwargs: See py_binary.
  """
  binary_name = name + ".binary"

  # TODO(mattmoor): Consider using par_binary instead, so that
  # a single target can be used for all three.
  native.py_binary(name=binary_name, deps=deps + layers, **kwargs)

  # TODO(mattmoor): Consider what the right way to switch between
  # Python 2/3 support might be.  Perhaps just overriding `base`,
  # but perhaps we can be smarter about selecting a py2 vs. py3
  # distroless base?

  # TODO(mattmoor): Consider making the directory into which the app
  # is placed configurable.
  index = 0
  base = base or "@py_image_base//image"
  for dep in layers:
    this_name = "%s.%d" % (name, index)
    dep_layer(name=this_name, base=base, dep=dep)
    base = this_name
    index += 1

  app_layer(name=name, base=base, entrypoint=['/usr/bin/python'],
            binary=binary_name, layers=layers)
