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
"""An implementation of container_pull based on google/containerregistry.

This wraps the containerregistry.tools.fast_puller executable in a
Bazel rule for downloading base images without a Docker client to
construct new images.
"""

load(":new_pull.bzl", _pull="pull", _container_pull="new_container_pull")

def python(repository_ctx):
    """Resolves the python path.

    Args:
      repository_ctx: The repository context

    Returns:
      The path to the python interpreter
    """

    if "BAZEL_PYTHON" in repository_ctx.os.environ:
        return repository_ctx.os.environ.get("BAZEL_PYTHON")

    python_path = repository_ctx.which("python2")
    if not python_path:
        python_path = repository_ctx.which("python")
    if not python_path:
        python_path = repository_ctx.which("python.exe")
    if python_path:
        return python_path

    fail("rules_docker requires a python interpreter installed. " +
         "Please set BAZEL_PYTHON, or put it on your path.")

pull = _pull

# Pulls a container image.

# This rule pulls a container image into our intermediate format.  The
# output of this rule can be used interchangeably with `docker_build`.
container_pull = _container_pull
