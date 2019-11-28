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
"""Utility Rules for testing"""

def generate_deb(name, args = [], metadata_compression_type = "none"):
    args_str = "--metadata_compression " + metadata_compression_type
    if args:
        args_str = " -a" + " -a ".join(args)
    native.genrule(
        name = name,
        outs = [name + ".deb"],
        cmd = "$(location :gen_deb) -p {name} {args_str} -o $@".format(
            name = name,
            args_str = args_str,
        ),
        tools = [":gen_deb"],
    )

def _rule_with_symlinks_impl(ctx):
    f = ctx.actions.declare_file("foo.txt")
    ctx.actions.write(f, "test content")
    runfiles = ctx.runfiles(files = [f], symlinks = {"foo-symlink.txt": f})
    return DefaultInfo(runfiles = runfiles)

rule_with_symlinks = rule(
    implementation = _rule_with_symlinks_impl,
)
