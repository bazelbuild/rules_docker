#!/usr/bin/env bash
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

# Testing script consumed by the container_repro_test rule that compares
# two images.
# Two images are considered to be identical when they both have the same
# digest and ID. On a mismatch of one of those values, the test fails
# and produces the summary of the images' differences.

set -ex

imgs_differ=false

function cmp_sha_files() {
  local file1="${1}"
  local file2="${2}"
  local content_type="${3}"

  local diff_ret=0
  diff $file1 $file2 &>/dev/null || diff_ret=$?
  echo === Comparing image "${content_type}"s ===
  if [ $diff_ret = 0 ]; then
  	echo Both images have the same SHA256 "${content_type}": "$(<$file1)"
  elif [ $diff_ret = 1 ]; then
  	echo Images have different SHA256 "${content_type}"s
  	echo First image "${content_type}": "$(<$file1)"
  	echo Reproduced image "${content_type}": "$(<$file2)"
    imgs_differ=true
  else
    echo diff command exited with error.
    exit 1
  fi
}

# Compare image digests.
img1_digest_file=%{img1_path}/%{img_name}.digest
img2_digest_file=%{img2_path}/%{img_name}.digest
cmp_sha_files $img1_digest_file $img2_digest_file "digest"

# Compare image IDs
img1_id_file="$(readlink -f %{img1_path}/%{img_name}.id)"
img2_id_file="$(readlink -f %{img2_path}/%{img_name}.id)"
cmp_sha_files "$img1_id_file" "$img2_id_file" "ID"

# Run the container_diff tool if images differ.
if [ "$imgs_differ" = true ]; then
  echo === Images are different. Running container_diff tool ===
  img1_tar=%{img1_path}/%{img_name}.tar
  img2_tar=%{img2_path}/%{img_name}.tar
  %{container_diff_tool} diff $img1_tar $img2_tar %{container_diff_args}
  exit $((1-%{success_exit}))
fi

exit %{success_exit}
