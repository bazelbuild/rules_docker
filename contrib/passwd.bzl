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

def _build_homedirs_tar(ctx):
    homedirs = []
    owners_map = {}
    for entry in ctx.attr.entries:
        homedir = entry[PasswdFileContentProvider].home
        owners_map[homedir] = "{uid}.{gid}".format(
            uid=entry[PasswdFileContentProvider].uid,
            gid=entry[PasswdFileContentProvider].gid)
        homedirs.append(homedir)
    args = ["--output=" + ctx.outputs.homedirs_tar.path, "--mode=0700"]
    args += ["--empty_dir=%s" % homedir for homedir in homedirs]
    args += ["--owners=%s=%s" % (key, owners_map[key]) for key in owners_map]

    ctx.actions.run(
        executable=ctx.executable.build_tar,
        inputs = [],
        outputs = [ctx.outputs.homedirs_tar],
        mnemonic="HomedirsPackageTar",
        arguments = args,
    )

def _passwd_file_impl(ctx):
    """Core implementation of passwd_file."""
    f = "".join(["%s:x:%s:%s:%s:%s:%s\n" % (
        entry[PasswdFileContentProvider].username,
        entry[PasswdFileContentProvider].uid,
        entry[PasswdFileContentProvider].gid,
        entry[PasswdFileContentProvider].info,
        entry[PasswdFileContentProvider].home,
        entry[PasswdFileContentProvider].shell,
    ) for entry in ctx.attr.entries])
    passwd_file = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(output = passwd_file, content = f)

    _build_homedirs_tar(ctx)

    return DefaultInfo(files = depset([passwd_file]))


passwd_entry = rule(
    attrs = {
        "username": attr.string(mandatory = True),
        "uid": attr.int(default = 1000),
        "gid": attr.int(default = 1000),
        "info": attr.string(default = "user"),
        "home": attr.string(default = "/home"),
        "shell": attr.string(default = "/bin/bash"),
    },
    implementation = _passwd_entry_impl
)

passwd_file = rule(
    attrs = {
        "entries": attr.label_list(
            allow_empty = False,
            providers = [PasswdFileContentProvider],
        ),
        "build_tar": attr.label(
            default = Label("//container:build_tar"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    },
    executable = False,
    outputs = {
        "homedirs_tar": "%{name}-homedirs.tar",
    },
    implementation = _passwd_file_impl,
)
