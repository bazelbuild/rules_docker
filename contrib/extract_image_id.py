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

import tarfile
from json import JSONDecoder
import sys

tar_path = sys.argv[1]

tar = tarfile.open(tar_path, mode='r')


decoder = JSONDecoder()
# Extracts it as a file object (not to the disk)
manifest = tar.extractfile("manifest.json").read().decode("utf-8")
manifest = decoder.decode(manifest)[0]

config_file = manifest["Config"]

id = config_file.split(".")[0]

print(id)
