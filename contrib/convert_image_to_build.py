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

"""Convert a docker save JSON files to a BUILD file so docker_import can read it."""

import gzip
import json
import os
import os.path
import shutil
import sys
import tarfile

def convert_manifest(infile, outfile):
  with open(infile, "r") as fp:
    json_obj =  json.load(fp)
    dirname = os.path.dirname(infile)
    dir = os.path.relpath(dirname, os.path.dirname(outfile))
    config = json_obj[0]["Config"]
    layers = json_obj[0]["Layers"]
    with open(outfile, "w") as of:
      of.write("""
load("@io_bazel_rules_docker//docker:docker.bzl", "docker_import")

docker_import(
    name = "image",
    layers = [%s],
    config = "%s/%s",
    visibility = ["//visibility:public"],
)
""" % (",".join(['"%s/%s.tgz"' % (dir, os.path.dirname(l)) for l in layers]), dir, config))

def extract_image(image, directory):
  with tarfile.open(image) as tar:
    tar.extractall(directory)
  for f in os.listdir(directory):
    d = os.path.join(directory, f)
    l = os.path.join(d, "layer.tar")
    if os.path.isdir(d) and os.path.exists(l):
      with gzip.open(d + ".tgz", "wb") as f_out, open(l, "rb") as f_in:
        shutil.copyfileobj(f_in, f_out)
      os.remove(l)

if __name__ == '__main__':
  if len(sys.argv) < 4:
    sys.stderr.write("Usage: %s infile directory build_file\n" % sys.argv[0])
    sys.exit(1)
  extract_image(sys.argv[1], sys.argv[2])
  convert_manifest(os.path.join(sys.argv[2], "manifest.json"), sys.argv[3])
