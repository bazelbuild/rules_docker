# Copyright 2018 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Basic validation of go_image targets."""

import os
import tarfile
import unittest

class TestGoImage(unittest.TestCase):


  def _test_file(self, path):
    tf = tarfile.open('tests/go/image-layer.tar')
    for mem in tf.getmembers():
      if mem.name == '/app/tests/go/app':
        return
    self.fail('failed to find /app/tests/go/app')

  def test_image(self):
    self._test_file('tests/go/image-layer.tar')

  def test_image_build_binary(self):
    self._test_file('tests/go/image_build_binary-layer.tar')


if __name__ == "__main__":
  unittest.main()
