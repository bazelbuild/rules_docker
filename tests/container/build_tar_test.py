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
        output_file.list(verbose=True)
        contained_names = output_file.getnames()

      # Assert all files from the source directory appear in the output tar file.
      for source_file in glob.iglob("./tests/container/testdata/files/*"):
        self.assertIn('./specifieddir/files/' + path.basename(source_file), contained_names)

  def testPackageNameParserValidMetadata(self):
    metadata = """
Package: test
Description: Dummy
Version: 1.2.4
"""
    self.assertEqual('test', TarFile.parse_pkg_name(metadata, "test.deb"))

  def testPackageNameParserInvalidMetadata(self):
    metadata = "Package Name: Invalid"
    self.assertEqual('test-invalid-pkg',
                     TarFile.parse_pkg_name(metadata, "some/path/test-invalid-pkg.deb"))


if __name__ == '__main__':
  unittest.main()
