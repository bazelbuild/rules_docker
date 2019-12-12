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
"""Functions for producing the hash of an artifact.

These functions pass down execution_requirements specified to the action
definitions they create.
"""

def sha256(ctx, artifact, execution_requirements = None):
    """Create an action to compute the SHA-256 of an artifact."""
    out = ctx.actions.declare_file(artifact.basename + ".sha256")
    ctx.actions.run(
        executable = ctx.executable.sha256,
        arguments = [artifact.path, out.path],
        inputs = [artifact],
        outputs = [out],
        mnemonic = "SHA256",
        execution_requirements = execution_requirements,
        # This is necessary until the interpreter used by py_binary is more
        # configurable. As a workaround, let users override $PATH with
        # --action_env for this rule.
        use_default_shell_env = True,
    )
    return out

tools = {
    "sha256": attr.label(
        default = Label("@bazel_tools//tools/build_defs/hash:sha256"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}
