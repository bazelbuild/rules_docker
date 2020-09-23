# Copyright 2020 The Bazel Authors. All rights reserved.
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
"""Extracts the last layer of a docker image out of an image tarball

Takes three arguments: the path to the image tarball, the output file for the layer, and the output file for the layer diffID
"""


from __future__ import print_function
from json import JSONDecoder
import hashlib
import sys
import tarfile


def extract_last_layer(tar_path, layer_path, diffid_path):
  """Extracts the last layer from a docker image from an image tarball

  Args:
    tar_path: str path to the tarball
    layer_path: str path for the output layer
    diffid_path: str path for the layer diff ID


  Returns:
    str the diff ID of the layer

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

  # Get the last layer tar path
  layers = manifest["Layers"]

  last_layer_path = layers[-1]

  layer_id = last_layer_path.split("/")[0]

  # Hash the layer as we extract it
  diff_id = hashlib.sha256()

  try:
    # Extract the layer from the image to the output path
    last_layer = tar.extractfile(last_layer_path)
    with open(layer_path, "wb") as f:
      # Extract in blocks, to avoid loading the entire layer in memory
      while True:
        buf = last_layer.read(4096)
        if buf:
          diff_id.update(buf)
          f.write(buf)
        else:
          break
  except Exception as e:
    print((
        "Unable to extract last layer {} to {}, make sure {} "
        "is a valid docker image and that the layer path is writable\n").format(layer_id, layer_path, tar_path),
          e,
          file=sys.stderr)
    exit(1)

  # Output the diff ID hash
  diff_id_digest = diff_id.hexdigest()
  try:
    with open(diffid_path, "w") as f:
      f.write(diff_id_digest)
  except Exception as e:
    print("Unable to write layer Diff ID {} to {}, make sure the path is writeable\n".format(diff_id_digest, diffid_path), e, file=sys.stderr)
    exit(1)

  return layer_id


if __name__ == "__main__":
  print(extract_last_layer(sys.argv[1], sys.argv[2], sys.argv[3]))
