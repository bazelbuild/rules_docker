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
import hashlib
import json
import os
import sys
import tarfile

import six
from six.moves import cStringIO

from container import utils
from containerregistry.client import docker_name
from containerregistry.client.v1 import docker_image as v1_image
from containerregistry.client.v1 import save as v1_save
from containerregistry.client.v2_2 import save as v2_2_save
from containerregistry.client.v2_2 import v2_compat
from containerregistry.client.v2_2 import docker_http
from containerregistry.client.v2_2 import docker_image as v2_2_image

parser = argparse.ArgumentParser(
    description='Link together several layer shards.')

parser.add_argument('--output', action='store', required=True,
                    help='The output file, mandatory')

parser.add_argument('--tags', action='append', required=True,
                    help=('An associative list of fully qualified tag names '
                          'and the layer they tag. '
                          'e.g. ubuntu=deadbeef,gcr.io/blah/debian=baadf00d'))

parser.add_argument('--layer', action='append', required=True,
                    help=('Each entry is an equivalence class with 4 parts: '
                          'diff_id, blob_sum, unzipped layer, zipped layer.'))

parser.add_argument('--legacy', action='append',
                    help='A list of tarballs from which our images may derive.')

parser.add_argument('--stamp-info-file', action='append', required=False,
                    help=('If stamping these layers, the list of files from '
                          'which to obtain workspace information'))


class FromParts(v2_2_image.DockerImage):
  """This accesses a more efficient on-disk format than FromTarball.

  FromParts is similar to FromDisk, but leverages the fact that we have both
  compressed and uncompressed forms available.
  """

  def __init__(self, config_file, diffid_to_blobsum,
               blobsum_to_unzipped, blobsum_to_zipped, blobsum_to_legacy):
    self._config = config_file
    self._blobsum_to_unzipped = blobsum_to_unzipped
    self._blobsum_to_zipped = blobsum_to_zipped
    self._blobsum_to_legacy = blobsum_to_legacy
    config = json.loads(self._config)
    content = self.config_file().encode('utf-8')
    self._manifest = json.dumps({
        'schemaVersion': 2,
        'mediaType': docker_http.MANIFEST_SCHEMA2_MIME,
        'config': {
            'mediaType': docker_http.CONFIG_JSON_MIME,
            'size': len(content),
            'digest': 'sha256:' + hashlib.sha256(content).hexdigest()
        },
        'layers': [
            {
                'mediaType': docker_http.LAYER_MIME,
                'size': self.blob_size(diffid_to_blobsum[diff_id]),
                'digest': diffid_to_blobsum[diff_id]
            }
            for diff_id in config['rootfs']['diff_ids']
        ]
    }, sort_keys=True)

  def manifest(self):
    """Override."""
    return self._manifest

  def config_file(self):
    """Override."""
    return self._config

  # Could be large, do not memoize
  def uncompressed_blob(self, digest):
    """Override."""
    if digest not in self._blobsum_to_unzipped:
      return self._blobsum_to_legacy[digest].uncompressed_blob(digest)
    with open(self._blobsum_to_unzipped[digest], 'r') as reader:
      return reader.read()

  # Could be large, do not memoize
  def blob(self, digest):
    """Override."""
    if digest not in self._blobsum_to_zipped:
      return self._blobsum_to_legacy[digest].blob(digest)
    with open(self._blobsum_to_zipped[digest], 'r') as reader:
      return reader.read()

  def blob_size(self, digest):
    """Override."""
    if digest not in self._blobsum_to_zipped:
      return self._blobsum_to_legacy[digest].blob_size(digest)
    info = os.stat(self._blobsum_to_zipped[digest])
    return info.st_size

  # __enter__ and __exit__ allow use as a context manager.
  def __enter__(self):
    return self

  def __exit__(self, unused_type, unused_value, unused_traceback):
    pass


def create_bundle(output, tag_to_config, diffid_to_blobsum,
                  blobsum_to_unzipped, blobsum_to_zipped, blobsum_to_legacy):
  """Creates a Docker image from a list of layers.

  Args:
    output: the name of the docker image file to create.
    layers: the layers (tar files) to join to the image.
    tag_to_layer: a map from docker_name.Tag to the layer id it references.
    layer_to_tags: a map from the name of the layer tarball as it appears
            in our archives to the list of tags applied to it.
  """

  with tarfile.open(output, 'w') as tar:
    def add_file(filename, contents):
      info = tarfile.TarInfo(filename)
      info.size = len(contents)
      tar.addfile(tarinfo=info, fileobj=cStringIO.StringIO(contents))

    tag_to_image = {}
    for (tag, config) in six.iteritems(tag_to_config):
      tag_to_image[tag] = FromParts(
          config, diffid_to_blobsum,
          blobsum_to_unzipped, blobsum_to_zipped, blobsum_to_legacy)

    v2_2_save.multi_image_tarball(tag_to_image, tar)


def main():
  args = parser.parse_args()

  tag_to_config = {}
  stamp_info = {}
  diffid_to_blobsum = {}
  blobsum_to_unzipped = {}
  blobsum_to_zipped = {}

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
    (fq_tag, config_filename) = elts

    formatted_tag = fq_tag.format(**stamp_info)
    tag = docker_name.Tag(formatted_tag, strict=False)
    config_file = utils.ExtractValue(config_filename)

    # Add the mapping in one direction.
    tag_to_config[tag] = config_file

  # Do this first so that if there is overlap with the loop below it wins.
  blobsum_to_legacy = {}
  for tar in args.legacy or []:
    with v2_2_image.FromTarball(tar) as legacy_image:
      config_file = legacy_image.config_file()
      cfg = json.loads(config_file)
      fs_layers = list(reversed(legacy_image.fs_layers()))
      for i, diff_id in enumerate(cfg['rootfs']['diff_ids']):
        blob_sum = fs_layers[i]
        diffid_to_blobsum[diff_id] = blob_sum
        blobsum_to_legacy[blob_sum] = legacy_image

  for entry in args.layer:
    elts = entry.split('=')
    if len(elts) != 4:
      raise Exception('Expected associative list key=value, got: %s' % entry)
    (diffid_filename, blobsum_filename,
     unzipped_filename, zipped_filename) = elts

    diff_id = 'sha256:' + utils.ExtractValue(diffid_filename)
    blob_sum = 'sha256:' + utils.ExtractValue(diffid_filename)

    diffid_to_blobsum[diff_id] = blob_sum
    blobsum_to_unzipped[blob_sum] = unzipped_filename
    blobsum_to_zipped[blob_sum] = zipped_filename

  create_bundle(
      args.output, tag_to_config, diffid_to_blobsum,
      blobsum_to_unzipped, blobsum_to_zipped, blobsum_to_legacy)


if __name__ == '__main__':
  main()
