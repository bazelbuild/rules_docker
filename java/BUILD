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

# A java_runtime to use as --javabase for building/running java_image targets
# By default the javabase set in Bazel points to the @local_jdk.
# In order to build java_images with all their dependencies set we
# include all transitive deps, which will include the @local_jdk unless
# the default is overriden. Note java_image rules will work without use of
# these flags but will be notoriously bigger.
java_runtime(
    name = "jdk",
    srcs = [],
    java_home = "/usr/lib/jvm/java-8-openjdk-amd64",
)
