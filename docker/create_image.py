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
"""This tool creates a docker image from a layer and the various metadata."""

import argparse
import cStringIO
import gzip
import hashlib
import json
import sys
import tarfile

from docker import utils
from containerregistry.client import docker_name
from containerregistry.client.v1 import docker_image as v1_image
from containerregistry.client.v1 import save as v1_save
from containerregistry.client.v2_2 import docker_image as v2_2_image

parser = argparse.ArgumentParser(
    description='Create a Docker image tarball (shard).')

# Hardcoded docker versions that we are claiming to be.
DATA_FORMAT_VERSION = '1.0'

parser.add_argument('--output', action='store', required=True,
                    help='The output file.')

parser.add_argument('--layer', action='store', required=True,
                    help='Layer tar file that we are adding to this image.')

parser.add_argument('--config', action='store', required=True,
                    help='The JSON configuration file for this image.')

parser.add_argument('--base', action='store',
                    help='The base image file for this image.')

parser.add_argument('--metadata', action='store',
                    help='The legacy JSON metadata file for this layer.')

parser.add_argument('--repository', action='store',
                    help='The name of the repository to add this image.')

parser.add_argument('--name', action='store',
                    help='The symbolic name of this image.')

parser.add_argument('--tag', action='append', default=[],
                    help='The repository tags to apply to the image')


class ImageShard(v1_image.DockerImage):
  """Represents a single v1 image shard in a manner suitable for saving."""

  def __init__(self, tag, metadata, layer):
    self._tag = tag
    self._metadata = json.loads(metadata)
    self._layer = layer

  def top(self):
    """Override."""
    return self._metadata['id']

  def repositories(self):
    """Override."""
    return {
        '{registry}/{repository}'.format(
            registry=self._tag.registry,
            repository=self._tag.repository): {
                self._tag.tag: self.top()
            }
    }

  def json(self, layer_id):
    """Override."""
    return json.dumps(self._metadata, sort_keys=True)

  def layer(self, layer_id):
    """Override."""
    if layer_id != self.top():
      raise Exception('Shard only supports fetching the topmost layer')
    buf = cStringIO.StringIO()
    f = gzip.GzipFile(mode='wb', fileobj=buf)
    try:
      f.write(self._layer)
    finally:
      f.close()
    return buf.getvalue()

  def ancestry(self, layer_id):
    """Override."""
    # We lie to trick save.tarball
    return [self.top()]

  # __enter__ and __exit__ allow use as a context manager.
  def __enter__(self):
    return self

  def __exit__(self, unused_type, unused_value, unused_traceback):
    pass


def create_image(output,
                 layer,
                 config,
                 tags=None,
                 base=None,
                 metadata=None,
                 name=None,
                 repository=None):
  """Writes a docker image shard (single layer) to a tarball.

  Args:
    output: the name of the docker image file to create.
    layer: the layer content
    config: the configuration file for the image.
    tags: tags that apply to this image.
    base: a base layer (optional) to build on top of.
    metadata: the json metadata file for the top layer.
    name: symbolic name for this docker image.
    repository: repository name for this docker image.
  """
  tag = docker_name.Tag('{repository}:{tag}'.format(
      repository=repository, tag=name))

  with tarfile.open(name=output, mode='w') as tar:
    def add_file(filename, contents):
      info = tarfile.TarInfo(filename)
      info.size = len(contents)
      tar.addfile(tarinfo=info, fileobj=cStringIO.StringIO(contents))

    # Read the layer's metadata
    with open(metadata, 'r') as f:
      json_content = f.read()
    # Read the layer's content
    with open(layer, 'r') as f:
      layer_content = f.read()

    # We write the initial shard through v1 because it's easier to dupe into
    # doing the bulk of the work for us.  We then do our own v2.2
    # shard-saving, using as many of the facilities from the
    # containerregistry client as we can.
    with ImageShard(tag, json_content, layer_content) as v1_img:
      v1_save.tarball(tag, v1_img, tar)
      layer_file_name = v1_img.top() + '/layer.tar'

    # add the image config referenced by the Config section in the manifest
    # the name can be anything but docker uses the format below.
    with open(config, 'r') as f:
      config_file_content = f.read()
      identifier = hashlib.sha256(config_file_content).hexdigest()
      config_file_name = identifier + '.json'
      add_file(config_file_name, config_file_content)

    manifest_item = {
        'Config': config_file_name,
        'Layers': [layer_file_name],
        'RepoTags': tags or []
    }

    if base:
      with v2_2_image.FromTarball(base, allow_shards=True) as v2_2_img:
        parent = hashlib.sha256(v2_2_img.config_file()).hexdigest()
        manifest_item['Parent'] = 'sha256:' + parent

      for entry in utils.GetManifestFromTar(base):
        if entry['Config'].endswith(parent + '.json'):
          # Prepend the layers, since order matters.
          manifest_item['Layers'] = (
              entry.get('Layers', []) + manifest_item['Layers'])
          break

    manifest = [manifest_item]

    manifest_content = json.dumps(manifest, sort_keys=True)
    add_file('manifest.json', manifest_content)


# Main program to create a docker image. It expect to be run with:
# create_image --output=output_file \
#              [--base=base] \
#              --layer=@identifier=layer.tar \
#              --metadata=metadata.json \
#              --name=myname --repository=repositoryName \
#              --tag=repo/image:tag
# See the gflags declaration about the flags argument details.
def main():
  args = parser.parse_args()

  create_image(args.output, args.layer, args.config, args.tag,
               args.base, args.metadata, args.name, args.repository)

if __name__ == '__main__':
  main()
