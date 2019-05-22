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
"""Rules for creating group files and entries.

Rules modeled after passwd_entry and passwd_file in passwd.bzl
"""

GroupFileContentProviderInfo = provider(fields = [
    "groupname",
    "gid",
    "users",
])

def _group_entry_impl(ctx):
    """Creates a passwd_file_content_provider containing a single entry."""
    return [GroupFileContentProviderInfo(
        groupname = ctx.attr.groupname,
        gid = ctx.attr.gid,
        users = ctx.attr.users,
    )]

def _group_file_impl(ctx):
    f = "".join(
        ["%s:x:%s:%s\n" % (
            entry[GroupFileContentProviderInfo].groupname,
            entry[GroupFileContentProviderInfo].gid,
            ",".join(entry[GroupFileContentProviderInfo].users),
        ) for entry in ctx.attr.entries],
    )
    group_file = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(output = group_file, content = f)
    return DefaultInfo(files = depset([group_file]))

group_entry = rule(
    attrs = {
        "gid": attr.int(default = 1000),
        "groupname": attr.string(mandatory = True),
        "users": attr.string_list(),
    },
    implementation = _group_entry_impl,
)

group_file = rule(
    attrs = {
        "entries": attr.label_list(
            allow_empty = False,
            providers = [GroupFileContentProviderInfo],
        ),
    },
    executable = False,
    implementation = _group_file_impl,
)
