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
load("//skylib:path.bzl", "dirname", "filename")

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
        "output_file": attr.string(default = ""),
    },
    executable = False,
    outputs = {
        "out": "%{output_file}" or "%{name}",
    },
    implementation = _impl,
)

def passwd_tar(name, username, uid, gid, info, home, shell, passwd_file_name=""):
    file_name = passwd_file_name or "%s.file" %name
    output_file = filename(file_name)
    package_dir = dirname(file_name)
    passwd_file(
        name = output_file,
        username = username,
        uid = uid,
        gid = gid,
        info = info,
        home = home,
        shell = shell,
        output_file = output_file
    )
    pkg_tar(
        name = "%s" %name,
        package_dir = package_dir,
        srcs =  [ output_file],
    )

