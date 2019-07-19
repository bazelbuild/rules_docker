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

set -exu

# Generates a docker run command to run a automatic container release config
# validator released as a Docker image. Argument list:
# docker_path- Path to the docker executable.
# docker_run_args- Arguments to pass to docker run other than the working
#                  directory.
# spec_file- Absolute path to the YAML spec file to validate.
# spec_file_mount_path- The path to mount the spec file as in the docker
#                       container. This can be the same as spec_file but ideally
#                       it should be made shorter so that the messages printed
#                       by the checker mentioning the name of the file (which
#                       will be the mounted path) are more user friendly.
# docker_image- The docker image for the checker that will be run.
# cmd_args- Arguments to pass to the checker.

function guess_runfiles() {
    if [ -d ${BASH_SOURCE[0]}.runfiles ]; then
        # Runfiles are adjacent to the current script.
        echo "$( cd ${BASH_SOURCE[0]}.runfiles && pwd )"
    else
        # The current script is within some other script's runfiles.
        mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        echo $mydir | sed -e 's|\(.*\.runfiles\)/.*|\1|'
    fi
}

RUNFILES="${PYTHON_RUNFILES:-$(guess_runfiles)}"

# Load the checker image and remember its id.
image_id=$(%{image_id_loader} %{image_tar})
%{docker_path} load -i %{image_tar}

# Run the checker image.
%{docker_path} run %{docker_run_args} $image_id %{cmd_args}

