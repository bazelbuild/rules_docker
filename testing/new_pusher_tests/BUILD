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

load("@io_bazel_rules_docker//contrib:test.bzl", "container_test")

container_test(
    name = "new_push_verify_pushed_configs_and_files",
    configs = ["@io_bazel_rules_docker//tests/container/configs:verify_new_pusher.yaml"],
    image = "@verify_new_pusher_image_contents//image",
    tags = ["manual"],  # buildkite-incompatible
)
