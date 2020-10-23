# Copyright 2015 The Bazel Authors. All rights reserved.
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

#!/usr/bin/env bash

function extract_image_name () {
    # Extracts the image name (repo:tag) from the tarball without running it
    # Does not require docker to be installed

    image_tar=$1

    tar -xf "$image_tar" "manifest.json"
    i=1
    while [ true ]
    do
    if [ "$(cut -d '"' -f$i manifest.json)" = "RepoTags" ]
        then
        image_name=$(cut -d '"' -f$(expr $i + 2) manifest.json)
        break
    fi
    i=$(expr $i + 1)
    done
    echo $image_name
}

set -ex

image_tar=$1
new_image_name=$2

if [ $(extract_image_name $image_tar) = $new_image_name ]
then
    exit 0
else
    exit 1
fi
