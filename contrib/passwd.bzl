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

load(
    "//skylib:path.bzl",
    _join_path = "join",
)

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
        entry[PasswdFileContentProvider].shell,
    ) for entry in ctx.attr.entries])
    passwd_file = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(output = passwd_file, content = f)
    return DefaultInfo(files = depset([passwd_file]))

def _build_homedirs_tar(ctx, passwd_file):
    homedirs = []
    owners_map = {}
    for entry in ctx.attr.entries:
        homedir = entry[PasswdFileContentProvider].home
        owners_map[homedir] = "{uid}.{gid}".format(
            uid = entry[PasswdFileContentProvider].uid,
            gid = entry[PasswdFileContentProvider].gid,
        )
        homedirs.append(homedir)
    dest_file = _join_path(
        ctx.attr.passwd_file_pkg_dir,
        ctx.label.name,
    )
    args = [
        "--output=" + ctx.outputs.passwd_tar.path,
        "--mode=0o700",
        "--file=%s=%s" % (passwd_file.path, dest_file),
        "--modes=%s=%s" % (dest_file, ctx.attr.passwd_file_mode),
    ]
    args += ["--empty_dir=%s" % homedir for homedir in homedirs]
    args += ["--owners=%s=%s" % (key, owners_map[key]) for key in owners_map]
    ctx.actions.run(
        executable = ctx.executable.build_tar,
        inputs = [passwd_file],
        outputs = [ctx.outputs.passwd_tar],
        mnemonic = "PasswdTar",
        arguments = args,
    )

def _passwd_tar_impl(ctx):
    """Core implementation of passwd_tar."""
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

    _build_homedirs_tar(ctx, passwd_file)

    return DefaultInfo(files = depset([ctx.outputs.passwd_tar]))

passwd_entry = rule(
    attrs = {
        "gid": attr.int(default = 1000),
        "home": attr.string(default = "/home"),
        "info": attr.string(default = "user"),
        "shell": attr.string(default = "/bin/bash"),
        "uid": attr.int(default = 1000),
        "username": attr.string(mandatory = True),
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
    implementation = _passwd_file_impl,
)

passwd_tar = rule(
    attrs = {
        "build_tar": attr.label(
            default = Label("//container:build_tar"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
        "entries": attr.label_list(
            allow_empty = False,
            providers = [PasswdFileContentProvider],
        ),
        "passwd_file_mode": attr.string(default = "0o644"),
        "passwd_file_pkg_dir": attr.string(mandatory = True),
    },
    executable = False,
    outputs = {
        "passwd_tar": "%{name}.tar",
    },
    implementation = _passwd_tar_impl,
)
