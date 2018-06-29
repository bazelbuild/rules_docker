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

# The test script generated by the create_failing_test_for_compare_ids_test test rule
# This creates a new workspace and copies all required files into it, then runs the test
# which is expected to fail, and passes only if it fails.

#!/bin/bash

set -eux

# Create a new workspace where we will run bazel and make sure tests fail
mkdir -p new_temp_workspace_{name}
cd new_temp_workspace_{name}

touch WORKSPACE

echo > BUILD {test_code}

# Link the test files we will be using and make sure the links point to real files
# No second operand means it just links the file in the current directory,
# under the same name

# Link compare_ids_test.bzl
ln -s ../{bzl_path}
test -f $(basename {bzl_path})

# Link compare_ids_test.sh.tpl
ln -s ../{tpl_path}
test -f $(basename {tpl_path})

# Link extract_image_id.sh
ln -s ../{extractor_path}
test -f $(basename {extractor_path})


tar_num=0
for tar in {tars}
do
  # Link the supplied tars and rename them to 0.tar, 1.tar, etc.
  eval mv $(ln -vs ../$tar | cut -d " " -f1) ${tar_num}.tar
  test -f ${tar_num}.tar
  tar_num=$(expr $tar_num + 1)
done

# Save the output from the bazel call (this is in an if because the bazel
# call is expected to fail, but should not terminate the script)
if out="$(bazel test --test_output=all //:test 2>&1)"; then :; fi

for reg_exp in {reg_exps}
do
  if ! [[ {if_modifier} $out =~ $reg_exp ]]
  then
    echo "'$reg_exp'" did not match >&2
    exit 1
  fi
done

exit 0

