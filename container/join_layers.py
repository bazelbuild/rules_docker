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
from containerregistry.client.v2_2 import save as v2_2_save
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

parser.add_argument('--manifests', action='append', required=False,
                    help=('An associative list of fully qualified tag names '
                          'and the manifest associated'
                          'e.g. ubuntu=deadbeef,gcr.io/blah/debian=baadf00d'))

parser.add_argument('--layer', action='append', required=False,
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

  def __init__(self, config_file, manifest_file, diffid_to_blobsum,
               blobsum_to_unzipped, blobsum_to_zipped, blobsum_to_legacy):
    self._config = config_file
    self._manifest = manifest_file
    self._blobsum_to_unzipped = blobsum_to_unzipped
    self._blobsum_to_zipped = blobsum_to_zipped
    self._blobsum_to_legacy = blobsum_to_legacy
    self._diffid_to_blobsum = diffid_to_blobsum
    config = json.loads(self._config)

    content = self.config_file().encode('utf-8')
    # print("the content of config file: {}".format(content))

    self._manifest = json.dumps({
        'schemaVersion': 2,
        'mediaType': docker_http.MANIFEST_SCHEMA2_MIME,
        'config': {
            'mediaType': docker_http.CONFIG_JSON_MIME,
            'size': len(content),
            'digest': 'sha256:' + hashlib.sha256(content).hexdigest()
        },
        'layers': [
            self.diff_id_to_layer_manifest_json(diff_id)
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

    if self.blobsum_to_media_type(digest) == docker_http.FOREIGN_LAYER_MIME:
      return bytearray()
    elif digest not in self._blobsum_to_unzipped:
      return self._blobsum_to_legacy[digest].uncompressed_blob(digest)

    with open(self._blobsum_to_unzipped[digest], 'rb') as reader:
      return reader.read()

  # Could be large, do not memoize
  def blob(self, digest):
    """Override."""
    if digest not in self._blobsum_to_zipped:
      return self._blobsum_to_legacy[digest].blob(digest)
    with open(self._blobsum_to_zipped[digest], 'rb') as reader:
      return reader.read()

  def blob_size(self, digest):
    """Override."""
    if self.blobsum_to_media_type(digest) == docker_http.FOREIGN_LAYER_MIME:
      return self.blobsum_to_manifest_layer(digest)['size']
    elif digest not in self._blobsum_to_zipped:
      return self._blobsum_to_legacy[digest].blob_size(digest)
    info = os.stat(self._blobsum_to_zipped[digest])
    return info.st_size

  def diff_id_to_manifest_layer(self, diff_id):
    # print("the diff_id2: {}".format(diff_id))
    # print("the blobsum: {}".format(self._diffid_to_blobsum))  
    # print("the blobsum: {}".format(self._diffid_to_blobsum[diff_id])) 
    return self.blobsum_to_manifest_layer(self._diffid_to_blobsum[diff_id])

  def blobsum_to_manifest_layer(self, digest):
    # print("hellooooooooooooooooooooooooooooooo")
    # print("the diff_id: {}".format(digest))
    if self._manifest:
      manifest = json.loads(self._manifest)
      if 'layers' in manifest and manifest['layers']:
        for layer in manifest['layers']:
          if layer['digest'] == digest:
            return layer
    return None

  def blobsum_to_media_type(self, digest):
    manifest_layer = self.blobsum_to_manifest_layer(digest)
    if manifest_layer and manifest_layer['mediaType']:
      return manifest_layer['mediaType']
    return docker_http.LAYER_MIME

  def diff_id_to_layer_manifest_json(self, diff_id):
    manifest_layer = self.diff_id_to_manifest_layer(diff_id)

    if manifest_layer:
      return manifest_layer
    else:
      return {
          'mediaType': docker_http.LAYER_MIME,
          'size': self.blob_size(self._diffid_to_blobsum[diff_id]),
          'digest': self._diffid_to_blobsum[diff_id]
      }

  # __enter__ and __exit__ allow use as a context manager.
  def __enter__(self):
    return self

  def __exit__(self, unused_type, unused_value, unused_traceback):
    pass


def create_bundle(output, tag_to_config, tag_to_manifest, diffid_to_blobsum,
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
      manifest = None
      if tag in tag_to_manifest:
        manifest = tag_to_manifest[tag]
      tag_to_image[tag] = FromParts(
          config, manifest, diffid_to_blobsum,
          blobsum_to_unzipped, blobsum_to_zipped, blobsum_to_legacy)

    v2_2_save.multi_image_tarball(tag_to_image, tar)

def create_tag_to_file_content_map(stamp_info, tag_file_pairs):
  """
    Creates a Docker image tag to file content map.

    Args:
      stamp_info - Tag substitutions to make in the input tags, e.g. {BUILD_USER}
      tag_file_pairs - List of input tags and file names
          (e.g. ...:image=@bazel-out/...image.0.config)
  """
  tag_to_file_content = {}

  if tag_file_pairs:
    for entry in tag_file_pairs:
      elts = entry.split('=')
      if len(elts) != 2:
        raise Exception('Expected associative list key=value, got: %s' % entry)
      (fq_tag, filename) = elts

      formatted_tag = fq_tag.format(**stamp_info)
      tag = docker_name.Tag(formatted_tag, strict=False)
      file_contents = utils.ExtractValue(filename)

      # Add the mapping in one direction.
      tag_to_file_content[tag] = file_contents

  return tag_to_file_content

def main():
  args = parser.parse_args()

  tag_to_config = {}
  tag_to_manifest = {}
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

  tag_to_config = create_tag_to_file_content_map(stamp_info, args.tags)
  tag_to_manifest = create_tag_to_file_content_map(stamp_info, args.manifests)

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

  if args.layer:
    for entry in args.layer:
      elts = entry.split('=')
      if len(elts) != 4:
        raise Exception('Expected associative list key=value, got: %s' % entry)
      (diffid_filename, blobsum_filename,
      unzipped_filename, zipped_filename) = elts

      diff_id = 'sha256:' + utils.ExtractValue(diffid_filename)
      blob_sum = 'sha256:' + utils.ExtractValue(blobsum_filename)

      # print("\nxingaodebug: {}\n".format(diff_id))

      diffid_to_blobsum[diff_id] = blob_sum
      blobsum_to_unzipped[blob_sum] = unzipped_filename
      blobsum_to_zipped[blob_sum] = zipped_filename

  # add foreign layers
  #
  # Windows base images distributed by Microsoft are using foreign layers.
  # Foreign layers are not stored in the Docker repository like normal layers.
  # Instead they include a list of URLs where the layer can be downloaded.
  # This is done because Windows base images are large (2+GB).  When someone
  # pulls a Windows image, it downloads the foreign layers from those URLs
  # instead of requesting the blob from the registry.
  # When adding foreign layers through bazel, the actual layer blob is not
  # present on the system.  Instead the base image manifest is used to
  # describe the parent image layers.
  for tag, manifest_file in tag_to_manifest.items():
    manifest = json.loads(manifest_file)
    # print("\nxingaodebug the manifest is: {}\n".format(diff_id))
    if 'layers' in manifest and manifest['layers']:
      # print(manifest)
      config = json.loads(tag_to_config[tag])
      # print("\nxingaodebug the manifest layers is: {}\n".format(manifest['layers']))
      for i, layer in enumerate(manifest['layers']):
        diff_id = config['rootfs']['diff_ids'][i]
        if layer['mediaType'] == docker_http.FOREIGN_LAYER_MIME:
          blob_sum = layer['digest']
          diffid_to_blobsum[diff_id] = blob_sum

  create_bundle(
      args.output, tag_to_config, tag_to_manifest, diffid_to_blobsum,
      blobsum_to_unzipped, blobsum_to_zipped, blobsum_to_legacy)


if __name__ == '__main__':
  main()
