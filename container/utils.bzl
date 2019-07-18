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
"""Utility tools for container rules."""

def generate_legacy_dir(ctx, layers, config):
    """Generate a legacy directory from the image represented by the given layers
    and config to /image_runfiles.

    Args:
      ctx: the execution context
      layers: the list of layer blobs for a docker image
      config: the config file for the image

    Returns:
      The config file path and a list of directories for the generated symlinked files.
    """
    path = "image_runfiles/"
    temp_files = []
    layer_paths = []

    # Symlink layers to ./image_runfiles/<i>.tar.gz
    for i in range(len(layers)):
        layer_symlink = ctx.actions.declare_file(path + str(i) + ".tar.gz")
        temp_files.append(layer_symlink)
        layer_paths.append(layer_symlink)
        ctx.actions.run_shell(
            outputs = [layer_symlink],
            inputs = [layers[i]],
            command = "ln {src} {dst}".format(
                src = layers[i].path,
                dst = layer_symlink.path,
            ),
        )

    # Symlink config to ./image_runfiles/config.json
    config_symlink = ctx.actions.declare_file(path + "config.json")
    temp_files.append(config_symlink)
    ctx.actions.run_shell(
        outputs = [config_symlink],
        inputs = [config],
        command = "ln {src} {dst}".format(
            src = config.path,
            dst = config_symlink.path,
        ),
    )

    return {
        "config": config_symlink,
        "layers": layer_paths,
        "temp_files": temp_files,
    }
