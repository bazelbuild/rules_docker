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

package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

# This file fetched from
# wget "http://keyserver.ubuntu.com/pks/lookup?op=get&fingerprint=on&search=0xEB9B1D8886F44E2A"
# because it was being served with unstable contents, causing our CI
# to fail 50% of the time.
filegroup(
    name = "launchpad_openjdk_gpg",
    srcs = ["launchpad_openjdk_gpg.pub"],
    visibility = ["//tests/docker:__subpackages__"],
)
