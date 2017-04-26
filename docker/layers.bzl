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
"""Tools for dealing with Docker Image layers."""

load(":list.bzl", "reverse")
load(":path.bzl", _get_runfile_path="runfile")


def _extract_id(ctx, artifact):
  id_out = ctx.new_file(artifact.basename + ".id")
  name_out = ctx.new_file(artifact.basename + ".name")
  ctx.action(
      executable = ctx.executable.extract_id,
      arguments = [
          "--tarball", artifact.path,
          "--output_id", id_out.path,
          "--output_name", name_out.path],
      inputs = [artifact],
      outputs = [id_out, name_out],
      mnemonic = "ExtractID")
  return id_out, name_out


def get_from_target(ctx, attr_target, file_target):
  if hasattr(attr_target, "docker_layers"):
    return attr_target.docker_layers
  else:
    if not file_target:
      return []
    target = file_target[0]
    id_out, name_out = _extract_id(ctx, target)
    return [{
        "layer": target,
        # ID is actually the hash of the v2.2 configuration file,
        # which is the name of the json file within the tarball.
        "id": id_out,
        # Name is the v1 image identifier we've assigned.
        "name": name_out
    }]


def assemble(ctx, layers, tags_to_names, output):
  """Create the full image from the list of layers."""
  layers = [l["layer"] for l in layers]
  args = [
      "--output=" + output.path,
  ] + [
      "--tags=" + tag + "=@" + tags_to_names[tag].path
      for tag in tags_to_names
  ] + ["--layer=" + l.path for l in layers]
  inputs = layers + tags_to_names.values()
  ctx.action(
      executable = ctx.executable.join_layers,
      arguments = args,
      inputs = inputs,
      outputs = [output],
      mnemonic = "JoinLayers"
  )


def incremental_load(ctx, layers, images, output):
  """Generate the incremental load statement."""
  ctx.template_action(
      template = ctx.file.incremental_load_template,
      substitutions = {
          "%{load_statements}": "\n".join([
              "incr_load '%s' '%s' '%s'" % (_get_runfile_path(ctx, l["name"]),
                                            _get_runfile_path(ctx, l["id"]),
                                            _get_runfile_path(ctx, l["layer"]))
              # The last layer is the first in the list of layers.
              # We reverse to load the layer from the parent to the child.
              for l in reverse(layers)]),
          "%{tag_statements}": "\n".join([
              "tag_layer '%s' '%s' '%s'" % (
                  img,
                  _get_runfile_path(ctx, images[img]["name"]),
                  _get_runfile_path(ctx, images[img]["id"]))
              for img in images
          ])
      },
      output = output,
      executable = True)


tools = {
    "incremental_load_template": attr.label(
        default=Label("//docker:incremental_load_template"),
        single_file=True,
        allow_files=True),
    "join_layers": attr.label(
        default=Label("//docker:join_layers"),
        cfg="host",
        executable=True,
        allow_files=True),
    "extract_id": attr.label(
        default=Label("//docker:extract_id"),
        cfg="host",
        executable=True,
        allow_files=True),
}
