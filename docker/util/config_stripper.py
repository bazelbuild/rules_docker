#!/usr/bin/python

# Copyright 2017 The Bazel Authors. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import cStringIO
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile

_TIMESTAMP = '1970-01-01T00:00:00Z'

WHITELISTED_PREFIXES = ['sha256:', 'manifest', 'repositories']

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--in_tar_path', type=str,
                        help='Path to docker save tarball',
                        required=True)
    parser.add_argument('--out_tar_path', type=str,
                        help='Path to output stripped tarball',
                        required=True)
    args = parser.parse_args()

    return strip_tar(args.in_tar_path, args.out_tar_path)


def strip_tar(input, output):
    # Unpack the tarball, modify configs in place, and rearchive.
    # We need to take care to keep the files sorted.

    tempdir = tempfile.mkdtemp()
    with tarfile.open(name=input, mode='r') as it:
        it.extractall(tempdir)

    mf_path = os.path.join(tempdir, 'manifest.json')
    with open(mf_path, 'r') as mf:
        manifest = json.load(mf)
    for image in manifest:
        # Scrape each layer for any timestamps
        new_layers = []
        new_diff_ids = []
        for layer in image['Layers']:
          (new_layer_name, new_diff_id) = strip_layer(os.path.join(tempdir, layer))

          new_layers.append(new_layer_name)
          new_diff_ids.append(new_diff_id)

        # Change the manifest to reflect the new layer name
        image['Layers'] = new_layers

        config = image['Config']
        cfg_path = os.path.join(tempdir, config)
        new_cfg_path = strip_config(cfg_path, new_diff_ids)

        # Update the name of the config in the metadata object
        # to match it's new digest.
        image['Config'] = new_cfg_path

    # Rewrite the manifest with the new config names.
    with open(mf_path, 'w') as f:
        json.dump(manifest, f, sort_keys=True)

    # Collect the files before adding, so we can sort them.
    files_to_add = []
    for root, _, files in os.walk(tempdir):
        for f in files:
            if os.path.basename(f).startswith(tuple(WHITELISTED_PREFIXES)):
                name = os.path.join(root, f)
                os.utime(name, (0,0))
                files_to_add.append(name)

    with tarfile.open(name=output, mode='w') as ot:
        for f in sorted(files_to_add):
            # Strip the tempdir path
            arcname = os.path.relpath(f, tempdir)
            ot.add(f, arcname)

    shutil.rmtree(tempdir)
    return 0

def strip_layer(path):
    # The original layer tar is of the form <random string>/layer.tar, the
    # working directory is one level up from where layer.tar is.
    original_dir = os.path.normpath(os.path.join(os.path.dirname(path), '..'))

    buf = cStringIO.StringIO()

    # Go through each file/dir in the layer
    # Set its mtime to 0
    # If it's a file, add its content to the running buffer
    # Add it to the new gzip'd tar.
    with tarfile.open(name=path, mode='r') as it:
      with tarfile.open(fileobj=buf, mode='w') as ot:
        for tarinfo in it:
          # Use a deterministic mtime that doesn't confuse other programs,
          # e.g. Python.
          # Also see https://github.com/bazelbuild/bazel/issues/1299
          tarinfo.mtime = 946684800 # 2000-01-01 00:00:00.000 UTC
          if tarinfo.isfile():
            f = it.extractfile(tarinfo)
            ot.addfile(tarinfo, f)
          else:
            ot.addfile(tarinfo)

    # Create the new diff_id for the config
    tar = buf.getvalue()
    diffid = hashlib.sha256(tar).hexdigest()
    diffid = 'sha256:%s' % diffid

    # Compress buf to gz
    # Shelling out to bash gzip is noticeably faster than using python's gzip
    gzip_process = subprocess.Popen(
        ['gzip', '-nf'],
        stdout=subprocess.PIPE,
        stdin=subprocess.PIPE,
        stderr=subprocess.PIPE)
    gz = gzip_process.communicate(input=tar)[0]

    # Calculate sha of layer
    sha = hashlib.sha256(gz).hexdigest()
    new_name = 'sha256:%s' % sha
    with open(os.path.join(original_dir, new_name), 'w') as out:
      out.write(gz)

    shutil.rmtree(os.path.dirname(path))
    return (new_name, diffid)


def strip_config(path, new_diff_ids):
    with open(path, 'r') as f:
        config = json.load(f)
    config['created'] = _TIMESTAMP
    config['rootfs']['diff_ids'] = new_diff_ids

    # Base container info is not required and changes every build, so delete it.
    if 'container' in config:
      del config['container']
    if ('config' in config and
        'Hostname' in config['config']):
      del config['config']['Hostname']
    if ('container_config' in config and
        'Hostname' in config['container_config']):
      del config['container_config']['Hostname']
    if 'docker_version' in config:
      del config['docker_version']
    for entry in config['history']:
        entry['created'] = _TIMESTAMP

    config_str = json.dumps(config, sort_keys=True)
    with open(path, 'w') as f:
        f.write(config_str)

    # Calculate the new file path
    sha = hashlib.sha256(config_str).hexdigest()
    new_path = 'sha256:%s' % sha
    os.rename(path, os.path.join(os.path.dirname(path), new_path))
    return new_path


if __name__ == "__main__":
    sys.exit(main())
