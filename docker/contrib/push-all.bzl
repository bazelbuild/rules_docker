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
"""An implementation of docker_push based on google/containerregistry.

This variant of docker_push accepts a docker_bundle target and publishes
the embedded image references.
"""

def _impl(ctx):
  """Core implementation of docker_push."""
  stamp = ctx.attr.bundle.stamp
  images = ctx.attr.bundle.docker_images

  stamp_inputs = []
  if stamp:
    stamp_inputs = [ctx.info_file, ctx.version_file]

  stamp_arg = " ".join(["--stamp-info-file=%s" % f.short_path for f in stamp_inputs])

  scripts = []
  runfiles = []
  index = 0
  for tag in images:
    image = images[tag]
    # Leverage our efficient intermediate representation to push.
    legacy_base_arg = ""
    if image.get("legacy"):
      print("Pushing an image based on a tarball can be very " +
            "expensive.  If the image is the output of a " +
            "docker_build, consider dropping the '.tar' extension. " +
            "If the image is checked in, consider using " +
            "docker_import instead.")
      legacy_base_arg = "--tarball=%s" % image["legacy"].short_path
      runfiles += [image["legacy"]]

    blobsums = image.get("blobsum", [])
    digest_arg = " ".join(["--digest=%s" % f.short_path for f in blobsums])
    blobs = image.get("zipped_layer", [])
    layer_arg = " ".join(["--layer=%s" % f.short_path for f in blobs])
    config_arg = "--config=%s" % image["config"].short_path

    runfiles += [image["config"]] + blobsums + blobs

    out = ctx.new_file("%s.%d.push" % (ctx.label.name, index))
    ctx.template_action(
        template = ctx.file._tag_tpl,
        substitutions = {
            "%{stamp}": stamp_arg,
            "%{tag}": ctx.expand_make_variables("tag", tag, {}),
            "%{image}": "%s %s %s %s" % (
                legacy_base_arg, config_arg, digest_arg, layer_arg),
            "%{docker_pusher}": ctx.executable._pusher.short_path,
        },
        output = out,
        executable=True,
    )

    scripts += [out]
    runfiles += [out]
    index += 1

  ctx.file_action(
    content = "\n".join(["#!/bin/bash -e"] + [
      command.short_path + "&"
      for command in scripts
    ] + ["wait"]),
    output = ctx.outputs.executable,
    executable=True,
  )

  return struct(runfiles = ctx.runfiles(files = [
    ctx.executable._pusher
  ] + stamp_inputs + runfiles))

docker_push = rule(
    attrs = {
        "bundle": attr.label(mandatory = True),
        "_tag_tpl": attr.label(
            default = Label("//docker/contrib:push-tag.sh.tpl"),
            single_file = True,
            allow_files = True,
        ),
        "_pusher": attr.label(
            default = Label("@pusher//file"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    },
    executable = True,
    implementation = _impl,
)
