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

load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")

def _impl(ctx):
  """Core implementation of passwd_file."""

  f = "%s:x:%s:%s:%s:%s:%s\n" % (
      ctx.attr.username,
      ctx.attr.uid,
      ctx.attr.gid,
      ctx.attr.info,
      ctx.attr.home,
      ctx.attr.shell
  )
  ctx.file_action(
      output = ctx.outputs.out,
      content = f,
      executable=False
  )

passwd_file = rule(
    attrs = {
        "username": attr.string(mandatory = True),
        "uid": attr.int(default = 1000),
        "gid": attr.int(default = 1000),
        "info": attr.string(default = "user"),
        "home": attr.string(default = "/home"),
        "shell": attr.string(default = "/bin/bash"),
    },
    executable = False,
    outputs = {
        "out": "%{name}",
    },
    implementation = _impl,
)

def passwd_tar(name, username, uid, gid, info, home, shell, passwd_file_nm=""):
    tar_name = "%s" %name
    file_name = passwd_file_nm or "%s.file" %name
    passwd_file(
        name = file_name,
        username = username,
        uid = uid,
        gid = gid,
        info = info,
        home = home,
        shell = shell,
    )
    pkg_tar(
        name = tar_name,
        srcs =  [ file_name ]
    )

