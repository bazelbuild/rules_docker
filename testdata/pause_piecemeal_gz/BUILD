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

load("//container:container.bzl", "container_import")
load("//testdata/pause_piecemeal:layers.bzl", "PAUSE_LAYERS")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

[genrule(
    name = "extract_%s_gz" % id,
    srcs = ["//testdata:pause.tar"],
    outs = ["%s.tar.gz" % id],
    cmd = ("tar xOf $(location //testdata:pause.tar) %s/layer.tar " +
           "| gzip -n > $(location :%s.tar.gz)") % (id, id),
) for id in PAUSE_LAYERS]

# this needs to be in a seperate package than the rest of the testdata because
# it generates identically named artifacts as pause_piecemeal.
container_import(
    name = "image",
    config = "//testdata/pause_piecemeal:pause_config.json",
    layers = ["%s.tar.gz" % x for x in PAUSE_LAYERS],
)
