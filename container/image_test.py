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

import cStringIO
import datetime
import json
import os
import tarfile
import unittest

from containerregistry.client import docker_name
from containerregistry.client.v2_2 import docker_image as v2_2_image

TEST_DATA_TARGET_BASE='testdata'
DIR_PERMISSION=448 # decimal for oct 0700
PASSWD_FILE_MODE=420  # decimal for oct 0644

def TestData(name):
  return os.path.join(os.environ['TEST_SRCDIR'], 'io_bazel_rules_docker',
                      TEST_DATA_TARGET_BASE, name)

def TestImage(name):
  return v2_2_image.FromTarball(TestData(name + '.tar'))

def TestBundleImage(name, image_name):
  return v2_2_image.FromTarball(
    TestData(name + '.tar'), name=docker_name.Tag(image_name, strict=False))

class ImageTest(unittest.TestCase):

  def assertTarballContains(self, tar, paths):
    self.assertEqual(paths, tar.getnames())

  def assertLayerNContains(self, img, n, paths):
    buf = cStringIO.StringIO(img.blob(img.fs_layers()[n]))
    with tarfile.open(fileobj=buf, mode='r') as layer:
      self.assertTarballContains(layer, paths)

  def assertTopLayerContains(self, img, paths):
    self.assertLayerNContains(img, 0, paths)

  def assertConfigEqual(self, img, key, value):
    cfg = json.loads(img.config_file())
    self.assertEqual(value, cfg.get('config', {}).get(key))

  def assertDigest(self, img, digest):
    self.assertEqual(img.digest(), 'sha256:' + digest)

  def assertTarInfo(self, tarinfo, uid, gid, mode, isdir):
    self.assertEqual(tarinfo.uid, uid)
    self.assertEqual(tarinfo.gid, gid)
    self.assertEqual(tarinfo.mode, mode)
    self.assertEqual(tarinfo.isdir(), isdir)

  def test_files_base(self):
    with TestImage('files_base') as img:
      self.assertDigest(img, '2d2577b6c328f3505de6c43acf0f9c81e5188d40acb91124f4ac30a85b65c760')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_files_with_file_base(self):
    with TestImage('files_with_files_base') as img:
      self.assertDigest(img, '371de40de1f50b7a59a9a7a3297454d8c2ed6b210158e3cb4687a62e6f3e7527')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_files_in_layer_with_file_base(self):
    with TestImage('files_in_layer_with_files_base') as img:
      self.assertDigest(img, '4b008d8241bdbbe930d72d8f0ee7b61d11561946db0fd52d02dbcb8842b3a958')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertLayerNContains(img, 2, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './baz'])
      self.assertLayerNContains(img, 0, ['.', './bar'])

  def test_tar_base(self):
    with TestImage('tar_base') as img:
      self.assertDigest(img, 'df626b895bc8c7b18e6615ac09ffbd0693268a24a817a94030ff88c37602147e')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './usr', './usr/bin', './usr/bin/unremarkabledeath'])
      # Check that this doesn't have a configured entrypoint.
      self.assertConfigEqual(img, 'Entrypoint', None)

  def test_tar_with_tar_base(self):
    with TestImage('tar_with_tar_base') as img:
      self.assertDigest(img, 'fc867d1606f3b54228ef9b2a3dcda56f2d2056bfcd1e0a18da3a0e7b86b95798')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_tars_in_layer_with_tar_base(self):
    with TestImage('tars_in_layer_with_tar_base') as img:
      self.assertDigest(img, '80f850359828f763ae544f9b7725f89755f1a28a80738a514735becae60924af')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, [
          './usr', './usr/bin', './usr/bin/unremarkabledeath'])

  def test_directory_with_tar_base(self):
    with TestImage('directory_with_tar_base') as img:
      self.assertDigest(img, 'ad11d32eb4b2d3abd01ce599a4200b20cf1c545ce870b174d28fd717c558a58c')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './foo', './foo/asdf', './foo/usr',
        './foo/usr/bin', './foo/usr/bin/miraclegrow'])

  def test_files_with_tar_base(self):
    with TestImage('files_with_tar_base') as img:
      self.assertDigest(img, 'f6f74908187196165c75ccabf1e419255a7217f282f2989020ac6873b6b4a741')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_workdir_with_tar_base(self):
    with TestImage('workdir_with_tar_base') as img:
      self.assertDigest(img, 'fe996f674b45b5d446e8eedd66cf2f6cfaddd9949e56f71d1a4963db40763145')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [])
      # Check that the working directory property has been properly configured.
      self.assertConfigEqual(img, 'WorkingDir', '/tmp')

  def test_tar_with_files_base(self):
    with TestImage('tar_with_files_base') as img:
      self.assertDigest(img, 'b791c09580efa5b2e961897a98facb46432e964558cfdbdbf153f0f2662a2465')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_docker_tarball_base(self):
    with TestImage('docker_tarball_base') as img:
      self.assertDigest(img, 'cc3ca2b7307e79ad52c6e8878740f86dcfe7055d2b7118aaa10b52cbba8b9898')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_layers_with_docker_tarball_base(self):
    with TestImage('layers_with_docker_tarball_base') as img:
      self.assertDigest(img, '927b3b98286e16727e2144152efb90f7394b0ad37d16668d40ce22b9e49debf9')
      self.assertEqual(5, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, ['.', './baz'])

  def test_base_with_entrypoint(self):
    with TestImage('base_with_entrypoint') as img:
      self.assertDigest(img, '813cb4af1c3f73cc2b5f837a61dca6a62335b87e5cd762e780286ca99f71ac83')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'ExposedPorts', {'8080/tcp': {}})

  def test_dashdash_entrypoint(self):
    with TestImage('dashdash_entrypoint') as img:
      self.assertDigest(img, 'da7146845e924f2b70fd6caa2b9c0f41a7d58e2fb51311f158a6255675347584')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar', '--'])

  def test_derivative_with_cmd(self):
    with TestImage('derivative_with_cmd') as img:
      self.assertDigest(img, 'd9756678b73e8ed342866f3694618f85a45430a01f89694580c76659445a7ccb')
      self.assertEqual(3, len(img.fs_layers()))

      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'Cmd', ['arg1', 'arg2'])
      self.assertConfigEqual(
        img, 'ExposedPorts', {'8080/tcp': {}, '80/tcp': {}})

  def test_derivative_with_volume(self):
    with TestImage('derivative_with_volume') as img:
      self.assertDigest(img, 'efe2b256ca249c3b49465edb893631c711a21a3891cda66d70d65e2781332908')
      self.assertEqual(2, len(img.fs_layers()))

      # Check that the topmost layer has the volumes exposed by the bottom
      # layer, and itself.
      self.assertConfigEqual(img, 'Volumes', {
        '/asdf': {}, '/blah': {}, '/logs': {}
      })

  def test_with_unix_epoch_creation_time(self):
    with TestImage('with_unix_epoch_creation_time') as img:
      self.assertDigest(img, '85113de3854559f724a23eed6afea5ceecd5fd4bf241cedaded8af0474d4f882')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('2009-02-13T23:31:30.120000Z', cfg.get('created', ''))

  def test_with_millisecond_unix_epoch_creation_time(self):
    with TestImage('with_millisecond_unix_epoch_creation_time') as img:
      self.assertDigest(img, 'e9412cb69da02e05fd5b7f8cc1a5d60139c091362afdc2488f9c8f7c508e5d3b')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('2009-02-13T23:31:30.123450Z', cfg.get('created', ''))

  def test_with_rfc_3339_creation_time(self):
    with TestImage('with_rfc_3339_creation_time') as img:
      self.assertDigest(img, '9aeef8cba32f3af6e95a08e60d76cc5e2a46de4847da5366bffeb1b3d7066d17')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('1989-05-03T12:58:12.345Z', cfg.get('created', ''))

  def test_with_stamped_creation_time(self):
    with TestImage('with_stamped_creation_time') as img:
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      created_str = cfg.get('created', '')
      self.assertNotEqual('', created_str)

      now = datetime.datetime.utcnow()

      created = datetime.datetime.strptime(created_str, '%Y-%m-%dT%H:%M:%S.%fZ')

      # The BUILD_TIMESTAMP is set by Bazel to Java's CurrentTimeMillis / 1000,
      # or env['SOURCE_DATE_EPOCH']. For Bazel versions before 0.12, there was
      # a bug where CurrentTimeMillis was not divided by 1000.
      # See https://github.com/bazelbuild/bazel/issues/2240
      # https://bazel-review.googlesource.com/c/bazel/+/48211
      # Assume that any value for 'created' within a reasonable bound is fine.
      self.assertLessEqual(now - created, datetime.timedelta(minutes=15))

  def test_with_default_stamped_creation_time(self):
    # {BUILD_TIMESTAMP} should be the default when `stamp = True` and
    # `creation_time` isn't explicitly defined.
    with TestImage('with_default_stamped_creation_time') as img:
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      created_str = cfg.get('created', '')
      self.assertNotEqual('', created_str)

      now = datetime.datetime.utcnow()

      created = datetime.datetime.strptime(created_str, '%Y-%m-%dT%H:%M:%S.%fZ')

      # The BUILD_TIMESTAMP is set by Bazel to Java's CurrentTimeMillis / 1000,
      # or env['SOURCE_DATE_EPOCH']. For Bazel versions before 0.12, there was
      # a bug where CurrentTimeMillis was not divided by 1000.
      # See https://github.com/bazelbuild/bazel/issues/2240
      # https://bazel-review.googlesource.com/c/bazel/+/48211
      # Assume that any value for 'created' within a reasonable bound is fine.
      self.assertLessEqual(now - created, datetime.timedelta(minutes=15))

  def test_with_env(self):
    with TestBundleImage(
        'with_env', 'bazel/%s:with_env' % TEST_DATA_TARGET_BASE) as img:
      self.assertDigest(img, '0b02ba27ff0d63d9430648e47743cba4ae8a1a4f9a80e0e1f9a1fa86835b2b17')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', ['bar=blah blah blah', 'foo=/asdf'])

  def test_layers_with_env(self):
    with TestImage('layers_with_env') as img:
      self.assertDigest(img, 'ecab0f39b4726e69c62747ce4c1662f697060eef23a26db719a47ea379b77d7f')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', ['PATH=$PATH:/tmp/a:/tmp/b:/tmp/c', 'a=b', 'x=y'])

  def test_dummy_repository(self):
    # We allow users to specify an alternate repository name instead of 'bazel/'
    # to prefix their image names.
    name = 'gcr.io/dummy/%s:dummy_repository' % TEST_DATA_TARGET_BASE
    with TestBundleImage('dummy_repository', name) as img:
      self.assertDigest(img, 'b15c4a4788ef0144c02469123432babebaa91b1b7c0607f4fafbfbac4824e2c1')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_with_double_env(self):
    with TestImage('with_double_env') as img:
      self.assertDigest(img, '931fc4d7205e4bca8236d3da8243413f7f0f17169ed33755bcc2ca633928de8e')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [
        'bar=blah blah blah',
        'baz=/asdf blah blah blah',
        'foo=/asdf'])

  def test_with_label(self):
    with TestImage('with_label') as img:
      self.assertDigest(img, '22709616008516169c29f30b72c0a566060cbd8959db2050ba1cae983983f830')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        'com.example.bar': '{"name": "blah"}',
        'com.example.baz': 'qux',
        'com.example.foo': '{"name": "blah"}',
      })

  def test_with_double_label(self):
    with TestImage('with_double_label') as img:
      self.assertDigest(img, '8eda9578d7eba0391ec791a6a87d34550b99b05fa55c403a64c4c12781e2cb29')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        'com.example.bar': '{"name": "blah"}',
        'com.example.baz': 'qux',
        'com.example.foo': '{"name": "blah"}',
        'com.example.qux': '{"name": "blah-blah"}',
      })

  def test_with_user(self):
    with TestImage('with_user') as img:
      self.assertDigest(img, '31d7d27f5e63516de98a3f67c382b7f86cfa1000d75c04a9e04c136162daa98b')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'User', 'nobody')

  def test_data_path(self):
    # Without data_path = "." the file will be inserted as `./test`
    # (since it is the path in the package) and with data_path = "."
    # the file will be inserted relatively to the testdata package
    # (so `./test/test`).
    with TestImage('no_data_path_image') as img:
      self.assertDigest(img, '2b32e6468a11c89ccbd2c386af3a2bfd4a365b2c1f36c0429d93e5ae048eee04')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test'])
    with TestImage('data_path_image') as img:
      self.assertDigest(img, 'c192f28dd8d03ec9afdb8f4a25cb007d82083ab8e5efd302c45c55e05c3cfae9')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test', './test/test'])

    # With an absolute path for data_path, we should strip that prefix
    # from the files' paths. Since the testdata images are in
    # //testdata and data_path is set to
    # "/tools/build_defs", we should have `docker` as the top-level
    # directory.
    with TestImage('absolute_data_path_image') as img:
      self.assertDigest(img, 'f001377d18507d390009490d2a969ec37f1ec16b02cee7066494f24ee8bb1e9e')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])
      # With data_path = "/", we expect the entire path from the repository
      # root.
    with TestImage('root_data_path_image') as img:
      self.assertDigest(img, 'f001377d18507d390009490d2a969ec37f1ec16b02cee7066494f24ee8bb1e9e')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])

  def test_flattened(self):
    with tarfile.open(TestData('flat.tar'), mode='r') as tar:
      self.assertTarballContains(tar, [
        '.', '/usr', '/usr/bin', '/usr/bin/java', './foo'])

  def test_bundle(self):
    with TestBundleImage('bundle_test', 'docker.io/ubuntu:latest') as img:
      self.assertDigest(img, '813cb4af1c3f73cc2b5f837a61dca6a62335b87e5cd762e780286ca99f71ac83')
      self.assertEqual(1, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'us.gcr.io/google-appengine/base:fresh') as img:
      self.assertDigest(img, '7e171f6c3ec60c98bc79012ba9022fc9aeccaff6b7eaa96bf1cda555cd0eedee')
      self.assertEqual(2, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'gcr.io/google-containers/pause:2.0') as img:
      self.assertDigest(img, '931fc4d7205e4bca8236d3da8243413f7f0f17169ed33755bcc2ca633928de8e')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_stamped_label(self):
    with TestImage('with_stamp_label') as img:
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {'BUILDER': os.environ['USER']})

  def test_pause_based(self):
    with TestImage('pause_based') as img:
      self.assertDigest(img, 'ea150b117be58b64e4e6d070d28db5fa4d3283c078da927ffb3b49fa01e8c85f')
      self.assertEqual(3, len(img.fs_layers()))

  def test_pause_piecemeal(self):
    with TestImage('pause_piecemeal') as img:
      self.assertDigest(img, 'ca362da80137d6e22de45cac9705271c694e63d87d4f98f1485288e83bda7334')
      self.assertEqual(2, len(img.fs_layers()))

  def test_pause_piecemeal_gz(self):
    with TestImage('pause_piecemeal_gz') as img:
      self.assertDigest(img, 'ca362da80137d6e22de45cac9705271c694e63d87d4f98f1485288e83bda7334')

  def test_build_with_tag(self):
    with TestBundleImage('build_with_tag', 'gcr.io/build/with:tag') as img:
      self.assertDigest(img, '1db3c9f3076f811a8d311ac6ee88251d621706ba8a80985685023b7e62b6cc14')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_passwd(self):
    with TestImage('with_passwd') as img:
      self.assertDigest(img, '27149ceaab154631346209b42c9494708210901fbb6e9f88cb9370fb51f30999')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/passwd'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/passwd').read()
        self.assertEqual(
          'root:x:0:0:Root:/root:/rootshell\nfoobar:x:1234:2345:myusernameinfo:/myhomedir:/myshell\n',
          content)
        self.assertEqual(layer.getmember("./etc/passwd").mode, PASSWD_FILE_MODE)

  def test_with_passwd_tar(self):
    with TestImage('with_passwd_tar') as img:
      self.assertDigest(img, 'b8f091c370d6a8a6f74e11327f52e579f73dd93d9cf82e39e83b3096bb0c2256')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/password', './root', './myhomedir'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/password').read()
        self.assertEqual(
          'root:x:0:0:Root:/root:/rootshell\nfoobar:x:1234:2345:myusernameinfo:/myhomedir:/myshell\n',
          content)
        self.assertEqual(layer.getmember("./etc/password").mode, PASSWD_FILE_MODE)
        self.assertTarInfo(layer.getmember("./root"), 0, 0, DIR_PERMISSION, True)
        self.assertTarInfo(layer.getmember("./myhomedir"), 1234, 2345, DIR_PERMISSION, True)


  def test_with_group(self):
    with TestImage('with_group') as img:
      self.assertDigest(img, 'd6384ee5db847e2c8a9e941d78c10bec987aa9cbd4b5b84847e20336ec09d49c')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/group'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/group').read()
        self.assertEqual('root:x:0:\nfoobar:x:2345:foo,bar,baz\n', content)

  def test_with_empty_files(self):
    with TestImage('with_empty_files') as img:
      self.assertDigest(img, 'ca83f384d82d79c39ed43dd79b8552e95c050041e7af8bed8ca8af0e291049e1')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './file1', './file2'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        for name in ('./file1', './file2'):
          memberfile = layer.getmember(name)
          self.assertEqual(0, memberfile.size)
          self.assertEqual(0o777, memberfile.mode)

  def test_with_empty_dirs(self):
    with TestImage('with_empty_dirs') as img:
      self.assertDigest(img, 'f4f102478ccee4a759c37fadfae09ebfdb1be5b4899faeb81ee24afb558b8868')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './foo', './bar'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        for name in ('./etc', './foo', './bar'):
          memberfile = layer.getmember(name)
          self.assertEqual(tarfile.DIRTYPE, memberfile.type)
          self.assertEqual(0o777, memberfile.mode)

  def test_py_image(self):
    with TestImage('py_image') as img:
      # Check the application layer, which is on top.
      self.assertTopLayerContains(img, [
        '.',
        './app',
        './app/testdata',
        './app/testdata/py_image.binary.runfiles',
        './app/testdata/py_image.binary.runfiles/io_bazel_rules_docker',
        './app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata',
        './app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata/py_image.py',
        './app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata/py_image.binary',
        './app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata/BUILD',
        './app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata/__init__.py',
        # TODO(mattmoor): The path normalization for symlinks should match
        # files to avoid this redundancy.
        '/app',
        '/app/testdata',
        '/app/testdata/py_image.binary.runfiles',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata/py_image_library.py',
        '/app/testdata/py_image.binary',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/external',
      ])

      # Check the library layer, which is one below our application layer.
      self.assertLayerNContains(img, 1, [
        '.',
        './app',
        './app/io_bazel_rules_docker',
        './app/io_bazel_rules_docker/testdata',
        './app/io_bazel_rules_docker/testdata/py_image_library.py',
      ])

  def test_cc_image(self):
    with TestImage('cc_image') as img:
      # Check the application layer, which is on top.
      self.assertTopLayerContains(img, [
        '.',
        './app',
        './app/testdata',
        './app/testdata/cc_image.binary.runfiles',
        './app/testdata/cc_image.binary.runfiles/io_bazel_rules_docker',
        './app/testdata/cc_image.binary.runfiles/io_bazel_rules_docker/testdata',
        './app/testdata/cc_image.binary.runfiles/io_bazel_rules_docker/testdata/cc_image.binary',
        './app/testdata/cc_image.binary.runfiles/io_bazel_rules_docker/testdata/BUILD',
        # TODO(mattmoor): The path normalization for symlinks should match
        # files to avoid this redundancy.
        '/app',
        '/app/testdata',
        '/app/testdata/cc_image.binary',
        '/app/testdata/cc_image.binary.runfiles',
        '/app/testdata/cc_image.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/cc_image.binary.runfiles/io_bazel_rules_docker/external',
      ])

      # The linker pulls the object files into the final binary,
      # so in C++ dependencies don't help when specified via `layers`.
      self.assertLayerNContains(img, 1, [])

  def test_java_image(self):
    with TestImage('java_image') as img:
      # Check the application layer, which is on top.
      self.assertTopLayerContains(img, [
        '.',
        './app',
        './app/io_bazel_rules_docker',
        './app/io_bazel_rules_docker/testdata',
        './app/io_bazel_rules_docker/testdata/java_image.binary.jar',
        './app/io_bazel_rules_docker/testdata/java_image.binary',
        './app/io_bazel_rules_docker/testdata/java_image.classpath'
      ])

      self.assertLayerNContains(img, 1, [
        '.',
        './app',
        './app/io_bazel_rules_docker',
        './app/io_bazel_rules_docker/testdata',
        './app/io_bazel_rules_docker/testdata/libjava_image_library.jar',
        './app/com_google_guava_guava',
        './app/com_google_guava_guava/jar',
        './app/com_google_guava_guava/jar/guava-18.0.jar',
      ])

      self.assertConfigEqual(img, 'Entrypoint', [
        '/usr/bin/java', '-cp',
        ':'.join([
          '/app/io_bazel_rules_docker/testdata/libjava_image_library.jar',
          '/app/io_bazel_rules_docker/../com_google_guava_guava/jar/guava-18.0.jar',
          '/app/io_bazel_rules_docker/testdata/java_image.binary.jar',
          '/app/io_bazel_rules_docker/testdata/java_image.binary'
        ]),
        '-XX:MaxPermSize=128M', 'examples.images.Binary', 'arg0', 'arg1', 'testdata/BUILD'])

  def test_war_image(self):
    with TestImage('war_image') as img:
      # Check the application layer, which is on top.
      self.assertTopLayerContains(img, [
        '.',
        './jetty',
        './jetty/webapps',
        './jetty/webapps/ROOT',
        './jetty/webapps/ROOT/WEB-INF',
        './jetty/webapps/ROOT/WEB-INF/lib',
        './jetty/webapps/ROOT/WEB-INF/lib/libwar_image.library.jar'
      ])

      self.assertLayerNContains(img, 1, [
        '.',
        './jetty',
        './jetty/webapps',
        './jetty/webapps/ROOT',
        './jetty/webapps/ROOT/WEB-INF',
        './jetty/webapps/ROOT/WEB-INF/lib',
        './jetty/webapps/ROOT/WEB-INF/lib/javax.servlet-api-3.0.1.jar',
      ])


  def test_cc_image_args(self):
    with TestImage('cc_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        '/app/testdata/cc_image.binary',
        'arg0',
        'arg1',
        'testdata/BUILD',
      ])

  # Re-enable once https://github.com/bazelbuild/rules_d/issues/14 is fixed.
  # def test_d_image_args(self):
  #  with TestImage('d_image') as img:
  #    self.assertConfigEqual(img, 'Entrypoint', [
  #      '/app/testdata/d_image_binary',
  #      'arg0',
  #      'arg1'])

  def test_py_image_args(self):
    with TestImage('py_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        '/usr/bin/python',
        '/app/testdata/py_image.binary',
        'arg0',
        'arg1',
        'testdata/BUILD',
      ])

  def test_py3_image_args(self):
    with TestImage('py3_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        '/usr/bin/python',
        '/app/testdata/py3_image.binary',
        'arg0',
        'arg1',
        'testdata/BUILD',
      ])

  def test_java_image_args(self):
    with TestImage('java_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        '/usr/bin/java',
        '-cp',
        '/app/io_bazel_rules_docker/testdata/libjava_image_library.jar:'
        +'/app/io_bazel_rules_docker/../com_google_guava_guava/jar/guava-18.0.jar:'
        +'/app/io_bazel_rules_docker/testdata/java_image.binary.jar:'
        +'/app/io_bazel_rules_docker/testdata/java_image.binary',
        '-XX:MaxPermSize=128M',
        'examples.images.Binary',
        'arg0',
        'arg1',
        'testdata/BUILD',
      ])

  def test_go_image_args(self):
    with TestImage('go_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        '/app/testdata/go_image.binary',
        'arg0',
        'arg1',
        'testdata/BUILD',
      ])

  def test_rust_image_args(self):
    with TestImage('rust_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        '/app/testdata/rust_image_binary',
        'arg0',
        'arg1',
        'testdata/BUILD',
      ])

  def test_scala_image_args(self):
    with TestImage('scala_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        '/usr/bin/java',
        '-cp',
        '/app/io_bazel_rules_docker/../com_google_guava_guava/jar/guava-18.0.jar:'+
        '/app/io_bazel_rules_docker/../io_bazel_rules_scala_scala_library/scala-library-2.11.12.jar:'+
        '/app/io_bazel_rules_docker/../io_bazel_rules_scala_scala_reflect/scala-reflect-2.11.12.jar:'+
        '/app/io_bazel_rules_docker/testdata/scala_image_library.jar:'+
        '/app/io_bazel_rules_docker/testdata/scala_image.binary.jar:'+
        '/app/io_bazel_rules_docker/testdata/scala_image.binary',
        'examples.images.Binary',
        'arg0',
        'arg1',
        'testdata/BUILD',
      ])

  def test_groovy_image_args(self):
    with TestImage('groovy_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        '/usr/bin/java',
        '-cp',
        '/app/io_bazel_rules_docker/testdata/libgroovy_image_library-impl.jar:'+
        '/app/io_bazel_rules_docker/../com_google_guava_guava/jar/guava-18.0.jar:'+
        '/app/io_bazel_rules_docker/../groovy_sdk_artifact/groovy-2.4.4/lib/groovy-2.4.4.jar:'+
        '/app/io_bazel_rules_docker/testdata/libgroovy_image.binary-lib-impl.jar:'+
        '/app/io_bazel_rules_docker/testdata/groovy_image.binary.jar:'+
        '/app/io_bazel_rules_docker/testdata/groovy_image.binary',
        'examples.images.Binary',
        'arg0',
        'arg1',
        'testdata/BUILD',
      ])

  def test_nodejs_image_args(self):
    with TestImage('nodejs_image') as img:
      self.assertConfigEqual(img, 'Entrypoint', [
        'sh',
        '-c',
        '/app/testdata/nodejs_image.binary',
        'arg0',
        'arg1'])


if __name__ == '__main__':
  unittest.main()
