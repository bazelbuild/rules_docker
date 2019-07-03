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
from datetime import datetime
import os
import shutil
import subprocess
import sys
from third_party.py import gflags

gflags.DEFINE_string('dest', None, 'The absolute path of file to copy the file to')
gflags.DEFINE_string('src', None, 'The absolute path of file to copy the file from')
gflags.DEFINE_string('key', None, 'The path to local file system file relative to store_location')
gflags.DEFINE_string('store_location', None, 'The location of the store relative to git root')
gflags.DEFINE_string('git_root', None, 'The absolute path to local git root')
gflags.DEFINE_string('method', 'get', 'FileSystemStore method either get, put')
gflags.DEFINE_string('status_file', None, 'The status file to record success or failure of the operation')
gflags.DEFINE_string('suppress_error', False, 'Suppress Error')

gflags.MarkFlagAsRequired('key')
gflags.MarkFlagAsRequired('store_location')


FLAGS = gflags.FLAGS

class LocalGitStore(object):
  """A class to get and put file in local GIT File System"""

  class LocalGitStoreError(Exception):
    pass

  def __init__(self, store_location, key, git_root, suppress_error, status_file=None):
    try:
      self.git_root = git_root or os.environ['GIT_ROOT']
      self.store_location = os.path.join(self.git_root, store_location)
      self.key = key
      self.status_file = status_file
      self.suppress_error = suppress_error
    except KeyError:
      raise LocalGitStore.LocalGitStoreError("Git root not found. Either use --git_root or  bazel command line flag --action_env=GIT_ROOT=`pwd`")

  def __enter__(self):
    self.status_code = 0
    return self

  def __exit__(self, t, v, traceback):
    if self.status_file:
      with open(self.status_file, "w") as f:
        f.write("{0}".format(self.status_code))

  @contextmanager
  def _execute(self, commands):
    try:
     for command in commands:
       self.status_code = subprocess.check_call(command, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
       self.status_code = e.returncode
       print(e)
       if self.suppress_error:
          return
       raise LocalGitStore.LocalGitStoreError(e)

  def get(self, get):
    """Get file and copy it to bazel workspace"""
    file_location = os.path.join(self.store_location, self.key)
    if os.path.exists(get) and self.suppress_error:
       os.remove(get)
    # Make sure the directory exists.
    dirname = os.path.dirname(get)
    if not os.path.exists(dirname):
      os.makedirs(dirname)
    self._execute(commands = [
       ['cp', file_location, get]
    ])

  def put_if_not_exists(self, src):
    file_location = os.path.join(self.store_location, self.key)
    if not os.path.exists(file_location):
      self.put(src)

  def put(self, src):
    """Put file from Bazel workspace to local file system"""
    file_location = os.path.join(self.store_location, self.key)
    self._execute(commands = [
      ['mkdir', '-p', os.path.dirname(file_location)],
      ['cp', src, file_location]
    ])
 

def main(unused_argv):
  if FLAGS.method == "get" and not FLAGS.dest:
    raise LocalGitStore.LocalGitStoreError(
      "Please specify the destination using --dest to store the file"
    )
  elif FLAGS.method == "put" and not FLAGS.src:
    raise LocalGitStore.LocalGitStoreError(
      "Please specify the file to put into store  using --src"
    )
  elif FLAGS.method not in ["put", "get"]:
    raise LocalGitStore.LocalGitStoreError("Method {0} not found".format(FLAGS.method))

  with LocalGitStore(store_location=FLAGS.store_location,
                     key=FLAGS.key,
                     git_root = FLAGS.git_root,
                     suppress_error=FLAGS.suppress_error,
                     status_file=FLAGS.status_file) as git_store:
    if FLAGS.method == "get":
      git_store.get(FLAGS.dest)
    elif FLAGS.method == "put":
      git_store.put_if_not_exists(FLAGS.src)


if __name__ == '__main__':
  main(FLAGS(sys.argv))
