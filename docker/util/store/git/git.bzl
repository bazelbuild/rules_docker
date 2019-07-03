#Copyright 2017 Google Inc. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

def git_store_get(ctx, store_location, key, artifact, suppress_error = "True"):
    """Create an action to get artifact from fs store."""
    status = ctx.actions.declare_file("{0}_get.status".format(ctx.label.name))
    args = [
        "--store_location",
        store_location,
        "--dest",
        artifact,
        "--method",
        "get",
        "--key",
        key,
        "--suppress_error",
        suppress_error,
        "--status_file",
        status.path,
    ]
    ctx.actions.run(
        executable = ctx.executable.git_store,
        arguments = args,
        outputs = [status],
        use_default_shell_env = True,
        mnemonic = "GetArtifact",
    )
    return status

def git_store_put(ctx, store_location, artifact, key):
    """Create an action to put artifact in fs store."""
    status = ctx.actions.declare_file("{0}_put.status".format(ctx.label.name))
    args = [
        "--store_location",
        store_location,
        "--src",
        artifact.path,
        "--method",
        "put",
        "--key",
        key,
        "--status_file",
        status.path,
    ]
    ctx.actions.run(
        outputs = [status],
        executable = ctx.executable.git_store,
        arguments = args,
        use_default_shell_env = True,
        inputs = [artifact],
        mnemonic = "PutArtifact",
    )
    return status

tools = {
    "git_store": attr.label(
        default = Label("//docker/util/store/git:git"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}
