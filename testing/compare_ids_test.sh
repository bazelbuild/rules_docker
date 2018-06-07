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

set -ex
BASEDIR=$(dirname "$0")

ID=""
for image in RUNFILES
do
  if [ echo $image | grep -q ".tar" ]
  then
    if [ $ID = "" ]
    then
      ID=$(BASEDIR/extract_image_id.sh $image)
    else
      if [ $(BASEDIR/extract_image_id.sh $image) != $ID ]
      then
        exit 1
      fi
    fi
  fi
done

exit 0
