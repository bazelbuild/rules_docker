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
"""This tool creates a docker image from a list of layers."""

import argparse
import cStringIO
import hashlib
import json
import os
import sys
import tarfile

from docker import utils
from containerregistry.client import docker_name
from containerregistry.client.v1 import docker_image as v1_image
from containerregistry.client.v1 import save as v1_save
from containerregistry.client.v2 import v1_compat
from containerregistry.client.v2_2 import save as v2_2_save
from containerregistry.client.v2_2 import v2_compat

parser = argparse.ArgumentParser(
    description='Link together several layer shards.')

parser.add_argument('--output', action='store', required=True,
                    help='The output file, mandatory')

parser.add_argument('--layer', action='append', required=True,
                    help='The tar files for layers to join.')

parser.add_argument('--tags', action='append', required=True,
                    help=('An associative list of fully qualified tag names '
                          'and the layer they tag. '
                          'e.g. ubuntu=deadbeef,gcr.io/blah/debian=baadf00d'))

parser.add_argument('--stamp-info-file', action='append', required=False,
                    help=('If stamping these layers, the list of files from '
                          'which to obtain workspace information'))

def create_image(output, layers, tag_to_layer=None, layer_to_tags=None):
  """Creates a Docker image from a list of layers.

  Args:
    output: the name of the docker image file to create.
    layers: the layers (tar files) to join to the image.
    tag_to_layer: a map from docker_name.Tag to the layer id it references.
    layer_to_tags: a map from the name of the layer tarball as it appears
            in our archives to the list of tags applied to it.
  """
  layer_to_tarball = {}
  for layer in layers:
    with tarfile.open(layer, 'r') as tarball:
      for path in tarball.getnames():
        if os.path.basename(path) != 'layer.tar':
          continue
        layer_id = os.path.basename(os.path.dirname(path))
        layer_to_tarball[layer_id] = layer

  with tarfile.open(output, 'w') as tar:
    def add_file(filename, contents):
      info = tarfile.TarInfo(filename)
      info.size = len(contents)
      tar.addfile(tarinfo=info, fileobj=cStringIO.StringIO(contents))

    tag_to_image = {}
    tag_to_v1_image = {}
    for (tag, top) in tag_to_layer.iteritems():
      v1_img = v1_image.FromShardedTarball(
          lambda layer_id: layer_to_tarball[layer_id], top)
      tag_to_v1_image[tag] = v1_img
      v2_img = v1_compat.V2FromV1(v1_img)
      v2_2_img = v2_compat.V22FromV2(v2_img)
      tag_to_image[tag] = v2_2_img

    v2_2_save.multi_image_tarball(tag_to_image, tar, tag_to_v1_image)


def main():
  args = parser.parse_args()

  tag_to_layer = {}
  layer_to_tags = {}
  stamp_info = {}

  if args.stamp_info_file:
    for infofile in args.stamp_info_file:
      with open(infofile) as info:
        for line in info:
          line = line.strip("\n")
          key, value = line.split(" ", 1)
          if key in stamp_info:
            print ("WARNING: Duplicate value for workspace status key '%s': "
                   "using '%s'" % (key, value))
          stamp_info[key] = value

  for entry in args.tags:
    elts = entry.split('=')
    if len(elts) != 2:
      raise Exception('Expected associative list key=value, got: %s' % entry)
    (fq_tag, layer_id) = elts

    formatted_tag = fq_tag.format(**stamp_info)
    tag = docker_name.Tag(formatted_tag)
    layer_id = utils.ExtractValue(layer_id)

    # Add the mapping in one direction.
    tag_to_layer[tag] = layer_id

    # Add the mapping in the other direction.
    layer_tags = layer_to_tags.get(layer_id, [])
    layer_tags.append(tag)
    layer_to_tags[layer_id] = layer_tags

  create_image(args.output, args.layer, tag_to_layer, layer_to_tags)


if __name__ == '__main__':
  main()
