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

def generate_legacy_dir(ctx, image_files):
    path = "image_runfiles/"

    temp_files = []

    # Generate symlinks for legacy formatted layers and config.json
    layer_counter = 0
    for f in image_files:
        if ".tar.gz" in f.basename:
            out_files = ctx.actions.declare_file(path + str(layer_counter) + ".tar.gz")
            layer_counter += 1
        elif "config" in f.basename:
            out_files = ctx.actions.declare_file(path + "config.json")
            config = out_files

        if out_files:
            temp_files.append(out_files)
        ctx.actions.run_shell(
            outputs = [out_files],
            inputs = [f],
            command = "ln {src} {dst}".format(
                src = f.path,
                dst = out_files.path,
            ),
        )

    return {
        "temp_files": temp_files,
        "config": config,
    }
