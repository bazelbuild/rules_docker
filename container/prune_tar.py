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
"""This tool build tar files by copying from a container_layer,
while excluding the specified files and directories."""

import argparse
import json
import tarfile

from pathlib import PurePosixPath


class TarFile(object):
    """A class to generate a pruned container layer."""

    def __init__(self, output, root_directory, layer, remove_paths):
        self.output = output
        self.root_directory = root_directory.rstrip('/')
        self.layer = layer
        self.remove_paths = remove_paths

    def __enter__(self):
        self.in_tar = tarfile.open(name=self.layer, mode='r:')
        self.out_tar = tarfile.open(name=self.output, mode='w:')
        return self

    def __exit__(self, t, v, traceback):
        self.out_tar.close()
        self.in_tar.close()

    def _add_entry(self, tarinfo):
        """Copy an entry from in_tar to out_tar."""
        if tarinfo.isfile():
            # use extractfile(tarinfo) instead of tarinfo.name to preserve
            # seek position in in_tar
            self.out_tar.addfile(tarinfo, self.in_tar.extractfile(tarinfo))
        else:
            self.out_tar.addfile(tarinfo)

    def _name_filter(self, path):
        """Returns false when the given path should be removed from the layer.

        Due to PurePosixPath.match not letting us specify whether the path is a file or a directory,
        this has the unfortunate effect that a pattern like `*.tmp` also matches a directory.

        Args:
           path: the path to the directory or file in the tar
        """
        if path.startswith(self.root_directory + '/'):
            path = path[len(self.root_directory):]
        else:
            # Always include all the root directories and files from other non-file directories.
            return True

        pure_path = PurePosixPath(path)
        for remove_path in self.remove_paths:
            if pure_path.match(remove_path):
                # Path itself matched glob pattern
                return False

        # PurePosixPath.match does not provide a way to match a directory and its contents;
        # that is, PurePosixPath('/usr/share/man/file').match('/usr/share/man') returns false.
        # It is not intuitive that `remove_paths = ["/usr/share/man"]` does not work,
        # requiring the workaround of `remove_paths = ["/usr/share/man", "/usr/share/man/**"]`.
        # Thus, we navigate up the directory structure and remove this path if the glob matches
        # any of the parent/ancestor directory, giving the effect that when a directory is removed,
        # its contents are also removed.
        pure_path_parent = pure_path.parent
        while pure_path != pure_path_parent:
            pure_path = pure_path_parent
            for remove_path in self.remove_paths:
                if (pure_path.match(remove_path)):
                    # Remove the contents of the directory.
                    return False

            pure_path_parent = pure_path.parent

        return True

    def process_tar(self):
        """Copies content of a tar file into the destination tar file,
        while excluding files and directories in remove_paths.
        Each path in remove_paths is a case-sensitive glob pattern.
        Removing a directory removes all its contents recursively.
        """
        for tar_info in self.in_tar:
            name = tar_info.name
            if self._name_filter(name):
                self._add_entry(tar_info)


def main(FLAGS):
    if FLAGS.manifest:
        with open(FLAGS.manifest, 'r') as f:
            manifest = json.load(f)
            remove_paths = manifest.get('remove_paths', [])
            unzipped_layer = manifest.get('unzipped_layer', '')
            with TarFile(FLAGS.output,
                         FLAGS.root_directory,
                         unzipped_layer,
                         remove_paths) as output:
                output.process_tar()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=str, required=True,
                        help='The output file, mandatory')

    parser.add_argument('--manifest', type=str,
                        help='JSON manifest of contents to exclude from the layer')

    parser.add_argument('--root_directory', type=str, default='./',
                        help='Default root directory is named "."'
                        'Windows docker images require this be named "Files" instead of "."')

    main(parser.parse_args())
