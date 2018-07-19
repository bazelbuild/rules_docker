#!/usr/bin/env python

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
import sys
import os
from extract_image_id import get_id
import argparse


def compare_ids(tars, id=None):

  for image in tars:
    current_id = get_id(image)
    if id == None:
      id = current_id
    elif current_id != id:
      exit(1)

  exit(0)


if __name__ == "__main__":
  parser = argparse.ArgumentParser()

  parser.add_argument("tars", nargs="+", type=str, default=[])

  parser.add_argument("--id", type=str, default=None)

  args = parser.parse_args()

  compare_ids(args.tars, args.id)
