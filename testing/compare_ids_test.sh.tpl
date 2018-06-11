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

function extract_image_id () {
  tar_path=$1

  if [ -e $tar_path ]
  then
    :
  else
    exit 1
  fi

  tar -xf $tar_path "manifest.json"
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

ID={id}

for image in {tars}
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
