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

# NOTE: If you are already loading the image, and are ok with getting the
# image name instead of the id (ex. if you are using it to run the image) then
# there is a much more efficient tool at #ADD LINK TO base-images-docker REPO HERE WHEN THEY ACCEPT THE PULL REQUEST

mkdir temp_for_extracting_id
cd temp_for_extracting_id
tar -xf ../$1 "manifest.json"
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
cd ..
rm -rf temp_for_extracting_id
echo $image_id
