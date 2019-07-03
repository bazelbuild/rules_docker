# Copyright 2017 Google Inc. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def deps():
    """
    Import external dependencies needed by targets in this package.
    """
    http_archive(
        name = "io_bazel_rules_python",
        sha256 = "9a3d71e348da504a9c4c5e8abd4cb822f7afb32c613dc6ee8b8535333a81a938",
        strip_prefix = "rules_python-fdbb17a4118a1728d19e638a5291b4c4266ea5b8",
        urls = ["https://github.com/bazelbuild/rules_python/archive/fdbb17a4118a1728d19e638a5291b4c4266ea5b8.tar.gz"],
    )
