#!/usr/bin/env bash
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

set -eu
set -o pipefail

bazel run //container/go/cmd/update_deps -- --repository=gcr.io/distroless/base --output=$PWD/go/go.bzl --architectures=amd64,arm,arm64,ppc64le,s390x
bazel run //container/go/cmd/update_deps -- --repository=gcr.io/distroless/static --output=$PWD/go/static.bzl --architectures=amd64,arm,arm64,ppc64le,s390x
bazel run //container/go/cmd/update_deps -- --repository=gcr.io/distroless/cc --output=$PWD/cc/cc.bzl
bazel run //container/go/cmd/update_deps -- --repository=gcr.io/distroless/python2.7 --output=$PWD/python/python.bzl
bazel run //container/go/cmd/update_deps -- --repository=gcr.io/distroless/python3 --output=$PWD/python3/python3.bzl
bazel run //container/go/cmd/update_deps -- --repository=gcr.io/distroless/java --output=$PWD/java/java.bzl
bazel run //container/go/cmd/update_deps -- --repository=gcr.io/distroless/java/jetty --output=$PWD/java/jetty.bzl
bazel run //container/go/cmd/update_deps -- --repository=gcr.io/google-appengine/debian9 --output=$PWD/nodejs/nodejs.bzl
