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
"""Compares the ids of the given valid image tarballs.

usage: compare_ids_test.py [-h] [--id ID] tars [tars ...]

positional arguments:
  tars

optional arguments:
  -h, --help  show this help message and exit
  --id ID

Used in compare_ids_test.bzl
  More info can be found there

"""
import argparse

from extract_image_id import get_id


def compare_ids(tars, id_=None):
  """Compares the ids of the given valid image tarballs.

  Args:
    tars: list of str paths to the image tarballs
    id_: (optional) the id we want the images to have
          if None, just makes sure they are all the same
  Raises:
    RuntimeError: Expected digest did not match actual image digest
  """
  for image in tars:
    current_id = get_id(image)
    if id_ is None:
      id_ = current_id
    elif current_id != id_:
      raise RuntimeError("Digest mismatch: actual {} vs expected {}".format(
          current_id,
          id_
          ))


if __name__ == "__main__":
  parser = argparse.ArgumentParser()

  parser.add_argument("tars", nargs="+", type=str, default=[])
  parser.add_argument("--id", type=str, default=None)

  args = parser.parse_args()

  compare_ids(args.tars, args.id)
