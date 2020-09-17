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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//container:container.bzl", "container_import")
load("//testdata/pause_piecemeal:layers.bzl", "PAUSE_LAYERS")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

PAUSE_CONFIG = "2b58359142b094165abfc9ad9c327c453a3eaa624d0c5ee8f0ed1ab50483603b.json"

genrule(
    name = "pause_config",
    srcs = ["//testdata:pause.tar"],
    outs = ["pause_config.json"],
    cmd = ("tar xOf $(location //testdata:pause.tar) %s " +
           "> $(location :pause_config.json)") % PAUSE_CONFIG,
)

[genrule(
    name = "extract_%s" % id,
    srcs = ["//testdata:pause.tar"],
    outs = ["%s.tar" % id],
    cmd = ("tar xOf $(location //testdata:pause.tar) %s/layer.tar " +
           "> $(location :%s.tar)") % (id, id),
) for id in PAUSE_LAYERS]

# this needs to be in a seperate package than the rest of the testdata because
# it generates identically named artifacts as pause_piecemeal_gz.
container_import(
    name = "image",
    config = ":pause_config.json",
    layers = ["%s.tar" % x for x in PAUSE_LAYERS],
)

bzl_library(
    name = "layers_bzl",
    srcs = ["layers.bzl"],
    visibility = ["//visibility:private"],
)
