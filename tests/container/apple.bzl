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
"""Rules to test issues related to pkg_tar's strip_prefix handling."""

def _create_banana_directory_impl(ctx):
    out = ctx.actions.declare_directory("banana")
    ctx.actions.run(
        executable = "bash",
        arguments = ["-c", "mkdir -p %s/pear && touch %s/pear/grape" % (out.path, out.path)],
        outputs = [out],
    )
    return [
        DefaultInfo(
            files = depset([out]),
        ),
    ]

create_banana_directory = rule(
    implementation = _create_banana_directory_impl,
)
