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
"""
This module contains a macro to generate container layers with empty files.
"""

load("//container:container.bzl", "container_layer")

def empty_layers(name, num_layers):
    """Generate the given number of empty layers prefixed with the given name
    """
    for i in range(num_layers):
        container_layer(
            name = "{}_{}".format(name, i),
            empty_files = ["file_{}.txt".format(i)],
        )
