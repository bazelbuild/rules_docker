#!/bin/bash

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

set -e

# The following code produces a 120MB file (30*2^22 bytes)
cat > input.txt <<EOF
01234567890123456789012345678
EOF

cp input.txt tmp.txt
for i in {1..22}; do
  cat tmp.txt >> input.txt
  cp input.txt tmp.txt
done

container/sha256 input.txt output.txt

expected=b89e2ebd615b1d32be9cec7bf687f3a00476835fe2ea8fb560394d79f420390c
if [ "$(cat output.txt)" != "$expected" ]; then
  echo "Wrong hash $(cat output.txt); expected $expected"
  exit 1
fi
