#!/bin/bash
#
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

set -ex

# This is a generated file that runs Kaniko inside a docker container, waits for
# it to finish running and copies the generated image tarball out of it.

# Copy the build context into the container.
data=$(%{docker_path} create -v %{kaniko_workspace} %{image_path})
%{docker_path} cp %{build_context_dir}/. ${data}:%{kaniko_workspace}

# Run the Kaniko executor container to build the image and extract as a tarball.
id=$(%{docker_path} run -d --volumes-from ${data} %{image_path} \
    --context=%{kaniko_workspace} --tarPath=%{extract_file} %{kaniko_flags})

%{docker_path} wait $id
%{docker_path} logs $id
%{docker_path} cp $id:%{extract_file} %{output}
%{docker_path} rm $id ${data}
