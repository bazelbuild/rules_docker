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

# This script is to be used for testing reproducibility in builds
# All data passed in must be tarballs

#!/bin/bash

function extract_image_id () {
  tar -xf $1 "manifest.json"
  i=1
  while [ true ]
  do
    if [ $(cut -d '"' -f$i manifest.json) = "Config" ]
      then
        image_id=$(cut -d '"' -f$(expr $i + 2) manifest.json | cut -d "." -f1)
        break
    fi
    i=$(expr $i + 1)
  done
  echo $image_id

}

set -exu

ID="0"
for image in $(find -name "*.tar*")
do
  if [ $ID = "0" ]
  then
    ID=$(extract_image_id $image)
  else
    if [ $(extract_image_id $image) != $ID ]
    then
      exit 1
    fi
  fi
done

exit 0
