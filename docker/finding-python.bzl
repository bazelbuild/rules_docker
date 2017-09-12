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
"""A rule for referencing the Python interpreter."""

def _impl(repository_ctx):
  # TODO(mattmoor): If this works, move it into something we set up
  # during docker_repositories() and use repository_ctx.symlink to
  # make it available to the downstream rules.
  if "BAZEL_PYTHON" in repository_ctx.os.environ:
    python_path = repository_ctx.os.environ.get("BAZEL_PYTHON")
  else:
    python_path = repository_ctx.which("python")
    if not python_path:
      python_path = repository_ctx.which("python.exe")

  if not python_path:
    fail("rules_docker requires a python interpreter installed. " +
         "Please set BAZEL_PYTHON, or put it on your path.")

  repository_ctx.file("BUILD", "exports_files(['python'])")
  repository_ctx.symlink(python_path, "python")


finding_python = repository_rule(
    implementation = _impl,
)
