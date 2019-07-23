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

# Generates a docker run command to run a automatic container release config
# validator released as a Docker image. Argument list:
# docker_path- Path to the docker executable.
# spec_file_path- Absolute path to the YAML spec file to validate.
# spec_file_container_path- The path to copy the spec file to in the docker
#                           container.
# image_name- The docker image for the checker that will be run.
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

# Create a new docker container that will run the checker.
container_id=$(%{docker_path} create %{image_name} %{cmd_args})

# Copy the spec file to the container. The "-L" is to follow symlinks.
%{docker_path} cp -L %{spec_file_path} $container_id:%{spec_file_container_path}

# Start the container that will run the checker logic.
%{docker_path} start $container_id

# Wait for the checker to finish running.
retcode=$(%{docker_path} wait $container_id)

# Print all logs generated by the container.
%{docker_path} logs $container_id

# Delete the container.
%{docker_path} rm $container_id

exit $retcode

