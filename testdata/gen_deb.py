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
"""A simple cross-platform helper to create a dummy debian package."""
from __future__ import print_function, unicode_literals
import argparse
import gzip
from io import BytesIO
import tarfile


def AddArFileEntry(fileobj, filename, content=b''):
  """Add a AR file entry to fileobj."""
  def write_utf8(f, t):
      f.write(t.encode('utf-8'))

  write_utf8(fileobj, (filename + '/').ljust(16))    # filename (SysV)
  write_utf8(fileobj, '0'.ljust(12))                 # timestamp
  write_utf8(fileobj, '0'.ljust(6))                  # owner id
  write_utf8(fileobj, '0'.ljust(6))                  # group id
  write_utf8(fileobj, '0644'.ljust(8))               # mode
  write_utf8(fileobj, str(len(content)).ljust(10))   # size
  fileobj.write(b'\x60\x0a')                    # end of file entry
  fileobj.write(content)
  if len(content) % 2 != 0:
    write_utf8(fileobj, '\n')  # 2-byte alignment padding


def add_file_to_tar(tar, filename, content, compression='none'):
   tarinfo = tarfile.TarInfo(filename)
   tarinfo.size = len(content)
   tar.addfile(tarinfo, fileobj=BytesIO(content))


def get_metadata(pkg_name, content=None):
  if content:
     return '\n'.join(content).encode()
  else:
     return '\n'.join([
         'Package: {0}'.format(pkg_name),
         'Description: Just a dummy description for dummy package {0}'.format(
             pkg_name),
     ]).encode()


def extension_for_compression(compression_type):
    if compression_type == 'gzip':
        return '.gz'
    elif compression_type == 'xz':
        return '.xz'
    elif compression_type == 'none':
        return ''
    else:
        return ValueError('Invalid value {0} for compression type'.format(compression_type))


def _compress_gzip(data):
    compressed_data = BytesIO()
    with gzip.GzipFile(fileobj=compressed_data, mode='wb', mtime=0) as f:
        f.write(data)
    return compressed_data.getvalue()


def _compress_xz(data):
    try:
        import lzma
        return lzma.compress(data)
    except ImportError:
        import subprocess
        if subprocess.call('which xz', shell=True, stdout=subprocess.PIPE):
            raise RuntimeError('Cannot handle .xz compression: xz not found.')
        xz_proc = subprocess.Popen(
            ['xz', '--compress', '--stdout'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE)
        return xz_proc.communicate(data)[0]


def compress_data(data, compression_type):
    if compression_type == 'none':
      return data
    if compression_type == 'gzip':
        return _compress_gzip(data)
    elif compression_type == 'xz':
        return _compress_xz(data)
    else:
        return ValueError('Invalid value {0} for compression type'.format(compression_type))


parser = argparse.ArgumentParser()

parser.add_argument('-p', action='store', dest='pkg_name',
                    help='Package name')

parser.add_argument('-a', action='append', dest='metadata',
                    help='Metadata for package')

parser.add_argument('-o', action='store', dest='outdir',
                    help='Destination dir')

parser.add_argument('--metadata_compression', action='store',
                    choices=['none', 'gzip', 'xz'], default='none',
                    help='Compression for control.tar')

if __name__ == '__main__':
  args = parser.parse_args()

  # Create data.tar
  tar = BytesIO()
  with tarfile.open('data.tar', mode='w', fileobj=tar) as f:
    tarinfo = tarfile.TarInfo('usr/')
    tarinfo.type = tarfile.DIRTYPE
    f.addfile(tarinfo)
    add_file_to_tar(f, 'usr/{0}'.format(args.pkg_name), 'toto\n'.encode())
  data = tar.getvalue()
  tar.close()

  # Create control.tar
  tar = BytesIO()
  metadata_filename = 'control.tar' + extension_for_compression(args.metadata_compression)
  with tarfile.open(metadata_filename, mode='w', fileobj=tar) as f:
    metadata_content = get_metadata(pkg_name=args.pkg_name,
                                    content=args.metadata)
    add_file_to_tar(f, 'control', metadata_content,
                    compression=args.metadata_compression)
  control = compress_data(tar.getvalue(), args.metadata_compression)
  tar.close()

  # Write the final AR archive (the deb package)
  with open(args.outdir, 'wb') as f:
    f.write('!<arch>\n'.encode())  # Magic AR header
    AddArFileEntry(f, 'debian-binary', '2.0'.encode())
    AddArFileEntry(f, metadata_filename, control)
    AddArFileEntry(f, 'data.tar', data)
