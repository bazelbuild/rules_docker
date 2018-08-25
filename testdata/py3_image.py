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
import sys
import os

from testdata import py_image_library

def main():
  """
  This method expects a valid file path as its third arg.
  """
  print('First: %d' % py_image_library.fn(1))
  print('Second: %d' % py_image_library.fn(2))
  print('Third: %d' % py_image_library.fn(3))
  print('Fourth: %d' % py_image_library.fn(4))
  print(sys.argv)
  if len(sys.argv) > 1:
    print(os.stat(sys.argv[2]))


if __name__ == '__main__':
  main()
