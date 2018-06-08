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

#!/bin/bash

# Extracts the image name (repo:tag) from the tarball without running it
# Does not require docker to be installed

mkdir temp_for_extracting_id
cd temp_for_extracting_id
tar -xf ../$1
i=1
while [ true ]
do
  if [ $(cut -d '"' -f$i manifest.json) = "RepoTags" ]
    then
      image_name=$(cut -d '"' -f$(expr $i + 2) manifest.json | cut -d "." -f1)
      break
  fi
  i=$(expr $i + 1)
done
cd ..
rm -rf temp_for_extracting_id
echo $image_name
