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
"""Extracts the id of a docker image from its tarball.

Takes one argument, the path to the tarball.
"""


from __future__ import print_function
from json import JSONDecoder
import sys
import tarfile

""" 
[CAAS] get_id is now actually retrieving the name of the image (not the id). Since docker engine 1.29 and it utilizing the containerd image store, we cannot reliably retrieve the id from the tar
"""
def get_id(tar_path):
  """Extracts the ~~id~~ name of a docker image from its tarball.

  Args:
    tar_path: str path to the tarball


  Returns:
    str ~~id~~name of the image

  """
  tar = tarfile.open(tar_path, mode="r")

  decoder = JSONDecoder()
  try:
    # Extracts it as a file object (not to the disk)
    manifest = tar.extractfile("manifest.json").read().decode("utf-8")
  except Exception as e:
    print((
        "Unable to extract manifest.json, make sure {} "
        "is a valid docker image.\n").format(tar_path),
          e,
          file=sys.stderr)
    exit(1)

  # Get the manifest dictionary from JSON
  manifest = decoder.decode(manifest)[0]

  # The name of the ~~config file is of the form <image_id>.json~~ image
  image_name = manifest["RepoTags"][0]

  return image_name


if __name__ == "__main__":
  print(get_id(sys.argv[1]))
