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

PasswdFileContentProvider = provider(
    fields = [
        "username",
        "uid",
        "gid",
        "info",
        "home",
        "shell",
        "name",
    ],
)

def _passwd_entry_impl(ctx):
  """Creates a passwd_file_content_provider containing a single entry."""
  return [PasswdFileContentProvider(
      username = ctx.attr.username,
      uid = ctx.attr.uid,
      gid = ctx.attr.gid,
      info = ctx.attr.info,
      home = ctx.attr.home,
      shell = ctx.attr.shell,
      name = ctx.attr.name,
  )]

def _passwd_file_impl(ctx):
  """Core implementation of passwd_file."""
  f = "".join(["%s:x:%s:%s:%s:%s:%s\n" % (
      entry[PasswdFileContentProvider].username,
      entry[PasswdFileContentProvider].uid,
      entry[PasswdFileContentProvider].gid,
      entry[PasswdFileContentProvider].info,
      entry[PasswdFileContentProvider].home,
      entry[PasswdFileContentProvider].shell) for entry in ctx.attr.entries])
  ctx.file_action(
      output = ctx.outputs.out,
      content = f,
      executable=False,
  )

passwd_entry = rule(
    attrs = {
        "username": attr.string(mandatory = True),
        "uid": attr.int(default = 1000),
        "gid": attr.int(default = 1000),
        "info": attr.string(default = "user"),
        "home": attr.string(default = "/home"),
        "shell": attr.string(default = "/bin/bash"),
    },
    implementation = _passwd_entry_impl,
)

passwd_file = rule(
    attrs = {
        "entries": attr.label_list(
            allow_empty = False,
            providers = [PasswdFileContentProvider],
        ),
    },
    executable = False,
    outputs = {
        "out": "passwd",
    },
    implementation = _passwd_file_impl,
)
