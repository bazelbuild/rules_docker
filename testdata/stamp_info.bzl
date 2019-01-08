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

"""Provides the stamp info file containing the Bazel non-volatile keys
"""

def _impl(ctx):
    output = ctx.outputs.out
    ctx.actions.run_shell(
        outputs = [output],
        inputs = [ctx.info_file],
        command = "cp {src} {dst}".format(
            src = ctx.info_file.path,
            dst = output.path,
        ),
    )

stamp_info = rule(
    implementation = _impl,
    outputs = {
        # The stamp file.
        "out": "%{name}.txt",
    },
)
