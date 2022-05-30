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
"""Tests for container build_tar tool"""

from container.build_tar import TarFile
import unittest
import tempfile
from os import path
import tarfile
import glob

class BuildTarTest(unittest.TestCase):

  def testAddsTarWithLongFileNames(self):
    with tempfile.TemporaryDirectory() as tmp:
      output_file_name = path.join(tmp, "output.tar")
      with TarFile(output_file_name, directory="/specifieddir", compression=None, root_directory=".", default_mtime=None,
                   enable_mtime_preservation=False, xz_path="", force_posixpath=False) as output_file:
        output_file.add_tar("./tests/container/testdata/expected.tar")

      with tarfile.open(output_file_name) as output_file:
        contained_names = output_file.getnames()

      # Assert all files from the source directory appear in the output tar file.
      for source_file in glob.iglob("./tests/container/testdata/files/*"):
        self.assertIn('./specifieddir/files/' + path.basename(source_file), contained_names)

  def testAddsTarWithLongPrefix(self):
    with tempfile.TemporaryDirectory() as tmp:
      output_file_name = path.join(tmp, "output.tar")
      prefix = 'a' * 99
      with TarFile(output_file_name, directory="/" + prefix, compression=None, root_directory=".", default_mtime=None,
                   enable_mtime_preservation=False, xz_path="", force_posixpath=False) as output_file:
        output_file.add_tar("./tests/container/testdata/expected.tar")

      with tarfile.open(output_file_name) as output_file:
        contained_names = output_file.getnames()

      # Assert all files from the source directory appear in the output tar file.
      for source_file in glob.iglob("./tests/container/testdata/files/*"):
        self.assertIn('./{}/files/{}'.format(prefix, path.basename(source_file)), contained_names)

  def testPackageNameParserValidMetadata(self):
    metadata = """
Package: test
Description: Dummy
Version: 1.2.4
"""
    self.assertEqual('test', TarFile.parse_pkg_name(metadata, "test.deb"))

  def testPkgMetadataStatusFileName(self):
    metadata = """Package: test
Description: Dummy
Version: 1.2.4
"""
    with tempfile.TemporaryDirectory() as tmp:
      # write control file into a metadata tar
      control_file_name = path.join(tmp, "control")
      with open(control_file_name, "w") as control_file:
        control_file.write(metadata)
      metadata_tar_file_name = path.join(tmp, "metadata.tar")
      with tarfile.open(metadata_tar_file_name, "w") as metadata_tar_file:
        metadata_tar_file.add(control_file_name, arcname="control")


      output_file_name = path.join(tmp, "output.tar")
      with TarFile(output_file_name, directory="/", compression=None, root_directory="./", default_mtime=None,
                   enable_mtime_preservation=False, xz_path="", force_posixpath=False) as output_file:
        output_file.add_pkg_metadata(metadata_tar_file_name, "ignored.deb")

      with tarfile.open(output_file_name) as output_file:
        contained_names = output_file.getnames()

        self.assertIn('./var/lib/dpkg/status.d/test', contained_names)

  def testPackageNameParserInvalidMetadata(self):
    metadata = "Package Name: Invalid"
    self.assertEqual('test-invalid-pkg',
                     TarFile.parse_pkg_name(metadata, "some/path/test-invalid-pkg.deb"))

  def testPkgMetadataMd5sumsFileName(self):
    metadata = """Package: test
Description: Dummy
Version: 1.2.4
"""
    md5sums ="""4006d28dbf6dfbe2c0fe695839e64cb3  usr/lib/python3/dist-packages/docutils/languages/cs.py
"""
    with tempfile.TemporaryDirectory() as tmp:
      # write control file into a metadata tar
      control_file_name = path.join(tmp, "control")
      with open(control_file_name, "w") as control_file:
        control_file.write(metadata)
      # write md5sums file into a metadata tar
      md5sums_file_name = path.join(tmp, "md5sums")
      with open(md5sums_file_name, "w") as md5sums_file:
        md5sums_file.write(md5sums)
      metadata_tar_file_name = path.join(tmp, "metadata.tar")

      with tarfile.open(metadata_tar_file_name, "w") as metadata_tar_file:
        metadata_tar_file.add(control_file_name, arcname="control")
        metadata_tar_file.add(md5sums_file_name, arcname="md5sums")

      output_file_name = path.join(tmp, "output.tar")
      with TarFile(output_file_name, directory="/", compression=None, root_directory="./", default_mtime=None,
                   enable_mtime_preservation=False, xz_path="", force_posixpath=False) as output_file:
        output_file.add_pkg_metadata(metadata_tar_file_name, "ignored.deb")

      with tarfile.open(output_file_name) as output_file:
        contained_names = output_file.getnames()

        self.assertIn('./var/lib/dpkg/status.d/test', contained_names)
        self.assertIn('./var/lib/dpkg/status.d/test.md5sums', contained_names)


if __name__ == '__main__':
  unittest.main()
