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
"""This tool build tar files from a list of inputs."""

from contextlib import contextmanager
import gzip
import io
import json
import os
import os.path
import subprocess
import sys
import re
import tarfile
import tempfile

from bazel_source.tools.build_defs.pkg import archive
from third_party.py import gflags

gflags.DEFINE_string('output', None, 'The output file, mandatory')
gflags.MarkFlagAsRequired('output')

gflags.DEFINE_multistring('file', [], 'A file to add to the layer')

gflags.DEFINE_string('manifest', None, 'JSON manifest of contents to add to the layer')

gflags.DEFINE_multistring('empty_file', [], 'An empty file to add to the layer')

gflags.DEFINE_multistring('empty_dir', [], 'An empty dir to add to the layer')

gflags.DEFINE_string(
    'mode', None, 'Force the mode on the added files (in octal).')

gflags.DEFINE_multistring(
    'empty_root_dir',
    [],
    'An empty root directory to add to the layer.  This will create a directory that'
    'is a peer of "root_directory".  "empty_dir" creates an empty directory inside of'
    '"root_directory"')

gflags.DEFINE_multistring('tar', [], 'A tar file to add to the layer')

gflags.DEFINE_multistring('deb', [], 'A debian package to add to the layer')

gflags.DEFINE_multistring(
    'link', [],
    'Add a symlink a inside the layer ponting to b if a:b is specified')
gflags.RegisterValidator(
    'link',
    lambda l: all(value.find(':') > 0 for value in l),
    message='--link value should contains a : separator')

gflags.DEFINE_string(
    'directory', None, 'Directory in which to store the file inside the layer')

gflags.DEFINE_string(
    'compression', None, 'Compression (`gz` or `bz2`), default is none.')

gflags.DEFINE_multistring(
    'modes', None,
    'Specific mode to apply to specific file (from the file argument),'
    ' e.g., path/to/file=0o455.')

gflags.DEFINE_multistring('owners', None,
                          'Specify the numeric owners of individual files, '
                          'e.g. path/to/file=0.0.')

gflags.DEFINE_string('owner', '0.0',
                     'Specify the numeric default owner of all files,'
                     ' e.g., 0.0')

gflags.DEFINE_string('owner_name', None,
                     'Specify the owner name of all files, e.g. root.root.')

gflags.DEFINE_multistring('owner_names', None,
                          'Specify the owner names of individual files, e.g. '
                          'path/to/file=root.root.')

gflags.DEFINE_string(
    'root_directory', './', 'Default root directory is named "."'
    'Windows docker images require this be named "Files" instead of "."')

gflags.DEFINE_string('xz_path', None,
                     'Specify the path to xz as a fallback when the Python '
                     'lzma module is unavailable.')

FLAGS = gflags.FLAGS


class TarFile(object):
  """A class to generates a Docker layer."""

  class DebError(Exception):
    pass

  PKG_NAME_RE = re.compile(r'Package:\s*(?P<pkg_name>\w+).*')
  DPKG_STATUS_DIR = '/var/lib/dpkg/status.d'
  PKG_METADATA_FILE = 'control'

  @staticmethod
  def parse_pkg_name(metadata, filename):
    pkg_name_match = TarFile.PKG_NAME_RE.match(str(metadata))
    if pkg_name_match:
      return pkg_name_match.group('pkg_name')
    else:
      return os.path.basename(os.path.splitext(filename)[0])

  def __init__(self, output, directory, compression, root_directory):
    self.directory = directory
    self.output = output
    self.compression = compression
    self.root_directory = root_directory

  def __enter__(self):
    self.tarfile = archive.TarFileWriter(
        self.output,
        self.compression,
        self.root_directory,
        default_mtime=0
    )
    return self

  def __exit__(self, t, v, traceback):
    self.tarfile.close()

  def add_file(self, f, destfile, mode=None, ids=None, names=None):
    """Add a file to the tar file.

    Args:
       f: the file to add to the layer
       destfile: the name of the file in the layer
       mode: force to set the specified mode, by
          default the value from the source is taken.
       ids: (uid, gid) for the file to set ownership
       names: (username, groupname) for the file to set ownership.
    `f` will be copied to `self.directory/destfile` in the layer.
    """
    dest = destfile.lstrip('/')  # Remove leading slashes
    if self.directory and self.directory != '/':
      dest = self.directory.lstrip('/') + '/' + dest
    # If mode is unspecified, derive the mode from the file's mode.
    if mode is None:
      mode = 0o755 if os.access(f, os.X_OK) else 0o644
    if ids is None:
      ids = (0, 0)
    if names is None:
      names = ('', '')
    dest = os.path.normpath(dest)
    self.tarfile.add_file(
        dest,
        file_content=f,
        mode=mode,
        uid=ids[0],
        gid=ids[1],
        uname=names[0],
        gname=names[1])

  def add_empty_file(self, destfile, mode=None, ids=None, names=None,
                     kind=tarfile.REGTYPE):
    """Add a file to the tar file.

    Args:
       destfile: the name of the file in the layer
       mode: force to set the specified mode, defaults to 644
       ids: (uid, gid) for the file to set ownership
       names: (username, groupname) for the file to set ownership.
       kind: type of the file. tarfile.DIRTYPE for directory.

    An empty file will be created as `destfile` in the layer.
    """
    dest = destfile.lstrip('/')  # Remove leading slashes
    # If mode is unspecified, assume read only
    if mode is None:
      mode = 0o644
    if ids is None:
      ids = (0, 0)
    if names is None:
      names = ('', '')
    dest = os.path.normpath(dest)
    self.tarfile.add_file(
        dest,
        content='' if kind == tarfile.REGTYPE else None,
        kind=kind,
        mode=mode,
        uid=ids[0],
        gid=ids[1],
        uname=names[0],
        gname=names[1])

  def add_empty_dir(self, destpath, mode=None, ids=None, names=None):
    """Add a directory to the tar file.

    Args:
       destpath: the name of the directory in the layer
       mode: force to set the specified mode, defaults to 644
       ids: (uid, gid) for the file to set ownership
       names: (username, groupname) for the file to set ownership.

    An empty file will be created as `destfile` in the layer.
    """
    self.add_empty_file(destpath, mode=mode, ids=ids, names=names,
                        kind=tarfile.DIRTYPE)

  def add_empty_root_dir(self, destpath, mode=None, ids=None, names=None):
    """Add a directory to the root of the tar file.

    Args:
       destpath: the name of the directory in the layer
       mode: force to set the specified mode, defaults to 644
       ids: (uid, gid) for the file to set ownership
       names: (username, groupname) for the file to set ownership.

    An empty directory will be created as `destfile` in the root layer.
    """
    original_root_directory = self.tarfile.root_directory
    self.tarfile.root_directory = destpath
    self.add_empty_dir(
        destpath, mode=mode, ids=ids, names=names)
    self.tarfile.root_directory = original_root_directory

  def add_tar(self, tar):
    """Merge a tar file into the destination tar file.

    All files presents in that tar will be added to the output file
    under self.directory/path. No user name nor group name will be
    added to the output.

    Args:
      tar: the tar file to add
    """
    root = None
    if self.directory and self.directory != '/':
      root = self.directory
    self.tarfile.add_tar(tar, numeric=True, root=root)

  def add_link(self, symlink, destination):
    """Add a symbolic link pointing to `destination`.

    Args:
      symlink: the name of the symbolic link to add.
      destination: where the symbolic link point to.
    """
    symlink = os.path.normpath(symlink)
    self.tarfile.add_file(symlink, tarfile.SYMTYPE, link=destination)

  @contextmanager
  def write_temp_file(self, data, suffix='tar', mode='wb'):
    # deb(5) states members may optionally be compressed with gzip or xz
    if suffix.endswith('.gz'):
      with gzip.GzipFile(fileobj=io.BytesIO(data)) as f:
        data = f.read()
      suffix = suffix[:-3]
    elif suffix.endswith('.xz'):
      data = self._xz_decompress(data)
      suffix = suffix[:-3]

    (_, tmpfile) = tempfile.mkstemp(suffix=suffix)
    try:
      with open(tmpfile, mode=mode) as f:
        f.write(data)
      yield tmpfile
    finally:
      os.remove(tmpfile)

  def add_pkg_metadata(self, metadata_tar, deb):
    try:
      with tarfile.open(metadata_tar) as tar:
        # Metadata is expected to be in a file.
        control_file_member = list(filter(lambda f: os.path.basename(f.name) == TarFile.PKG_METADATA_FILE, tar.getmembers()))
        if not control_file_member:
           raise self.DebError(deb + ' does not Metadata File!')
        control_file = tar.extractfile(control_file_member[0])
        metadata = b''.join(control_file.readlines())
        destination_file = os.path.join(TarFile.DPKG_STATUS_DIR,
                                        TarFile.parse_pkg_name(metadata, deb))
        with self.write_temp_file(data=metadata) as metadata_file:
          self.add_file(metadata_file, destination_file)
    except (KeyError, TypeError) as e:
      raise self.DebError(deb + ' contains invalid Metadata! Exeception {0}'.format(e))
    except Exception as e:
      raise self.DebError('Unknown Exception {0}. Please report an issue at'
                          ' github.com/bazelbuild/rules_docker.'.format(e))

  def add_deb(self, deb):
    """Extract a debian package in the output tar.

    All files presents in that debian package will be added to the
    output tar under the same paths. No user name nor group names will
    be added to the output.

    Args:
      deb: the tar file to add

    Raises:
      DebError: if the format of the deb archive is incorrect.
    """
    pkg_data_found = False
    pkg_metadata_found = False
    with archive.SimpleArFile(deb) as arfile:
      current = arfile.next()
      while current:
        parts = current.filename.split(".")
        name = parts[0]
        if parts[-1].lower() == 'xz':
          current.data = self._xz_decompress(current.data)
          ext = '.'.join(parts[1:-1])
        else:
            ext = '.'.join(parts[1:])
        if name == 'data':
          pkg_data_found = True
          # Add pkg_data to image tar
          with self.write_temp_file(suffix=ext, data=current.data) as tmpfile:
            self.add_tar(tmpfile)
        elif name == 'control':
          pkg_metadata_found = True
          # Add metadata file to image tar
          with self.write_temp_file(suffix=ext, data=current.data) as tmpfile:
            self.add_pkg_metadata(metadata_tar=tmpfile, deb=deb)
        current = arfile.next()

    if not pkg_data_found:
      raise self.DebError(deb + ' does not contains a data file!')
    if not pkg_metadata_found:
      raise self.DebError(deb + ' does not contains a control file!')

  @staticmethod
  def _xzcat_decompress(data):
    """Decompresses the xz-encrypted bytes in data by piping to xz."""
    if not FLAGS.xz_path:
      raise RuntimeError('Cannot handle .xz compression: xz not found.')

    xz_proc = subprocess.Popen(
      [FLAGS.xz_path, '--decompress', '--stdout'],
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE)
    return xz_proc.communicate(data)[0]

  def _xz_decompress(self, data):
    """Decompress xz-compressed bytes, using the lzma module when available, falling back to xzcat"""
    try:
      import lzma
      decompress = lzma.decompress
    except ImportError:
      try:
        from backports import lzma
        decompress = lzma.decompress
      except ImportError:
        decompress = self._xzcat_decompress
    return decompress(data)


def main(unused_argv):
  # Parse modes arguments
  default_mode = None
  if FLAGS.mode:
    # Convert from octal
    default_mode = int(FLAGS.mode, 8)

  mode_map = {}
  if FLAGS.modes:
    for filemode in FLAGS.modes:
      (f, mode) = filemode.split('=', 1)
      if f[0] == '/':
        f = f[1:]
      mode_map[f] = int(mode, 8)

  default_ownername = ('', '')
  if FLAGS.owner_name:
    default_ownername = FLAGS.owner_name.split('.', 1)
  names_map = {}
  if FLAGS.owner_names:
    for file_owner in FLAGS.owner_names:
      (f, owner) = file_owner.split('=', 1)
      (user, group) = owner.split('.', 1)
      if f[0] == '/':
        f = f[1:]
      names_map[f] = (user, group)

  default_ids = FLAGS.owner.split('.', 1)
  default_ids = (int(default_ids[0]), int(default_ids[1]))
  ids_map = {}
  if FLAGS.owners:
    for file_owner in FLAGS.owners:
      (f, owner) = file_owner.split('=', 1)
      (user, group) = owner.split('.', 1)
      if f[0] == '/':
        f = f[1:]
      ids_map[f] = (int(user), int(group))

  # Add objects to the tar file
  with TarFile(FLAGS.output, FLAGS.directory, FLAGS.compression, FLAGS.root_directory) as output:
    def file_attributes(filename):
      if filename.startswith('/'):
        filename = filename[1:]
      return {
          'mode': mode_map.get(filename, default_mode),
          'ids': ids_map.get(filename, default_ids),
          'names': names_map.get(filename, default_ownername),
      }

    if FLAGS.manifest:
      with open(FLAGS.manifest, 'r') as f:
        manifest = json.load(f)
        for f in manifest.get('files', []):
          output.add_file(f['src'], f['dst'], **file_attributes(f['dst']))
        for f in manifest.get('empty_files', []):
          output.add_empty_file(f, **file_attributes(f))
        for d in manifest.get('empty_dirs', []):
          output.add_empty_dir(d, **file_attributes(d))
        for d in manifest.get('empty_root_dirs', []):
          output.add_empty_root_dir(d, **file_attributes(d))
        for f in manifest.get('symlinks', []):
          output.add_link(f['linkname'], f['target'])
        for tar in manifest.get('tars', []):
          output.add_tar(tar)
        for deb in manifest.get('debs', []):
          output.add_deb(deb)

    for f in FLAGS.file:
      (inf, tof) = f.split('=', 1)
      output.add_file(inf, tof, **file_attributes(tof))
    for f in FLAGS.empty_file:
      output.add_empty_file(f, **file_attributes(f))
    for f in FLAGS.empty_dir:
      output.add_empty_dir(f, **file_attributes(f))
    for f in FLAGS.empty_root_dir:
      output.add_empty_root_dir(f, **file_attributes(f))
    for tar in FLAGS.tar:
      output.add_tar(tar)
    for deb in FLAGS.deb:
      output.add_deb(deb)
    for link in FLAGS.link:
      l = link.split(':', 1)
      output.add_link(l[0], l[1])


if __name__ == '__main__':
  main(FLAGS(sys.argv))
