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

def generate_legacy_dir(ctx, config, manifest, layers):
    """Generate a intermediate legacy directory from the image represented by the given layers and config to /image_runfiles.

    Args:
      ctx: the execution context
      config: the image config file
      manifest: the image manifest file
      layers: the list of layer tarballs

    Returns:
      The filepaths generated and runfiles to be made available.
      config: the generated config file.
      layers: the generated layer tarball files.
      temp_files: all the files generated to be made available at runtime.
    """

    # Construct image runfiles for input to pusher.
    image_files = [] + layers
    if config:
        image_files += [config]
    if manifest:
        image_files += [manifest]

    path = "image_runfiles/"
    layer_files = []

    # Symlink layers to ./image_runfiles/<i>.tar.gz
    for i in range(len(layers)):
        layer_symlink = ctx.actions.declare_file(path + str(i) + ".tar.gz")
        layer_files.append(layer_symlink)
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
        "layers": layer_files,
        "temp_files": [config_symlink] + layer_files,
    }
