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
DIR_PERMISSION=0o700
PASSWD_FILE_MODE=0o644
# Dictionary of key to value mappings in the Bazel stamp file
STAMP_DICT = {}

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
    self.maxDiff = None
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
      self.assertDigest(img, '1c1fcf1a9023510b85e7c7657633d4d475f19ec369bceeecf51ffc1d20b7d991')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_files_with_file_base(self):
    with TestImage('files_with_files_base') as img:
      self.assertDigest(img, 'dfe1c2ccf355654757ea34bfd52904979b8391df005fc6022685b3622aeb1f6f')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_files_in_layer_with_file_base(self):
    with TestImage('files_in_layer_with_files_base') as img:
      self.assertDigest(img, '46c2f6f35cbe02d2d00709fe05e3c7c7fc6e38bc21c3e18f936472cb6736817c')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertLayerNContains(img, 2, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './baz'])
      self.assertLayerNContains(img, 0, ['.', './bar'])

  def test_tar_base(self):
    with TestImage('tar_base') as img:
      self.assertDigest(img, 'ab9fa86e113af1d9afb616669e202020d4e86a9850d6da6bd9afe23f89e0a492')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './usr', './usr/bin', './usr/bin/unremarkabledeath'])
      # Check that this doesn't have a configured entrypoint.
      self.assertConfigEqual(img, 'Entrypoint', None)

  def test_tar_with_tar_base(self):
    with TestImage('tar_with_tar_base') as img:
      self.assertDigest(img, 'add16ea735d315ed6442cb5a9bbafd5e83b72661c24ef72a4342da8c8f1686dc')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_tars_in_layer_with_tar_base(self):
    with TestImage('tars_in_layer_with_tar_base') as img:
      self.assertDigest(img, 'c5081d3ba5900b902959c1b023db1165293371ed32984dc2953ef649c9b37419')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, [
          './usr', './usr/bin', './usr/bin/unremarkabledeath'])

  def test_directory_with_tar_base(self):
    with TestImage('directory_with_tar_base') as img:
      self.assertDigest(img, 'e2a9cc4845a726499a22c6f8eab253fb7fa98627eb63d8b41f8df6f1eb93541d')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './foo', './foo/asdf', './foo/usr',
        './foo/usr/bin', './foo/usr/bin/miraclegrow'])

  def test_files_with_tar_base(self):
    with TestImage('files_with_tar_base') as img:
      self.assertDigest(img, 'd45d37c42b785fbbc9695e81ace5da94c6b2ad3107df08a726d10fac63791eec')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_workdir_with_tar_base(self):
    with TestImage('workdir_with_tar_base') as img:
      self.assertDigest(img, '5d902f0e50b0dea025a16dfd8fdd3ac8692fea6ac830011b4cc979d5f683d1a7')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [])
      # Check that the working directory property has been properly configured.
      self.assertConfigEqual(img, 'WorkingDir', '/tmp')

  def test_tar_with_files_base(self):
    with TestImage('tar_with_files_base') as img:
      self.assertDigest(img, 'cff818161c13bbdf60a508db4913003d908b54926d01a6c129dee499380006fa')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_docker_tarball_base(self):
    with TestImage('docker_tarball_base') as img:
      self.assertDigest(img, 'e7749e74fa47cffc21b379965876d5a9f14f5d2a903fdfe96f741c98670e5f37')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_layers_with_docker_tarball_base(self):
    with TestImage('layers_with_docker_tarball_base') as img:
      self.assertDigest(img, '9cb35a8786fb6fa2ff1ddb7accddc045b08b802b8b97d8cc27c5054b4b9a8942')
      self.assertEqual(5, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, ['.', './baz'])

  def test_base_with_entrypoint(self):
    with TestImage('base_with_entrypoint') as img:
      self.assertDigest(img, '55e9d4c0d06433ceb8b82c46075547c1a886788c508eb8f83f57f450b57c1bf9')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'ExposedPorts', {'8080/tcp': {}})

  def test_dashdash_entrypoint(self):
    with TestImage('dashdash_entrypoint') as img:
      self.assertDigest(img, 'c5aac836b6785d6998891d0b60d5e5f1661f44d5257a05be40be80a18a26ad3b')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar', '--'])

  def test_derivative_with_cmd(self):
    with TestImage('derivative_with_cmd') as img:
      self.assertDigest(img, 'f02ce2d2ca68504a922644b22c1918fcb7468709830de9626a3d744fdc292b25')
      self.assertEqual(3, len(img.fs_layers()))

      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'Cmd', ['arg1', 'arg2'])
      self.assertConfigEqual(
        img, 'ExposedPorts', {'8080/tcp': {}, '80/tcp': {}})

  def test_derivative_with_volume(self):
    with TestImage('derivative_with_volume') as img:
      self.assertDigest(img, '3df2370ba6f2dc1201ad5e0b1fc98d6f7fbf1c8e0ea3628526049ce6ef03a396')
      self.assertEqual(2, len(img.fs_layers()))

      # Check that the topmost layer has the volumes exposed by the bottom
      # layer, and itself.
      self.assertConfigEqual(img, 'Volumes', {
        '/asdf': {}, '/blah': {}, '/logs': {}
      })

  def test_with_unix_epoch_creation_time(self):
    with TestImage('with_unix_epoch_creation_time') as img:
      self.assertDigest(img, '8b0831dbd59bad97acfa05c7579cdd395969a3e203286956d7ed6e4594aa298d')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual(u'2009-02-13T23:31:30.119999885Z', cfg.get('created', ''))

  def test_with_millisecond_unix_epoch_creation_time(self):
    with TestImage('with_millisecond_unix_epoch_creation_time') as img:
      self.assertDigest(img, '9574f947ef4f5b6b3e23c80b6339003ad71a385319e2fd9087a8c357606e360c')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual(u'2009-02-13T23:31:30.12345004Z', cfg.get('created', ''))

  def test_with_rfc_3339_creation_time(self):
    with TestImage('with_rfc_3339_creation_time') as img:
      self.assertDigest(img, '4560b374b18abe7c641c9242d2ef610a9bc5a5a7b03458c1575e24714287dfff')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual(u'1989-05-03T12:58:12.345Z', cfg.get('created', ''))

  # This test is flaky. If it fails, do a bazel clean --expunge_async and try again
  def test_with_stamped_creation_time(self):
    with TestImage('with_stamped_creation_time') as img:
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      created_str = cfg.get('created', '')
      self.assertNotEqual('', created_str)

      now = datetime.datetime.utcnow()

      created = datetime.datetime.strptime(created_str, '%Y-%m-%dT%H:%M:%SZ')

      # The BUILD_TIMESTAMP is set by Bazel to Java's CurrentTimeMillis / 1000,
      # or env['SOURCE_DATE_EPOCH']. For Bazel versions before 0.12, there was
      # a bug where CurrentTimeMillis was not divided by 1000.
      # See https://github.com/bazelbuild/bazel/issues/2240
      # https://bazel-review.googlesource.com/c/bazel/+/48211
      # Assume that any value for 'created' within a reasonable bound is fine.
      self.assertLessEqual(now - created, datetime.timedelta(minutes=15))

  # This test is flaky. If it fails, do a bazel clean --expunge_async and try again
  def test_with_default_stamped_creation_time(self):
    # {BUILD_TIMESTAMP} should be the default when `stamp = True` and
    # `creation_time` isn't explicitly defined.
    with TestImage('with_default_stamped_creation_time') as img:
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      created_str = cfg.get('created', '')
      self.assertNotEqual('', created_str)

      now = datetime.datetime.utcnow()

      created = datetime.datetime.strptime(created_str, '%Y-%m-%dT%H:%M:%SZ')

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
      self.assertDigest(img, 'a221f35173c4ece08b7d21278905a6a14aace84d095b4fed0a3aeb13a3167ca5')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [u'bar=blah blah blah', u'foo=/asdf'])

  def test_layers_with_env(self):
    with TestImage('layers_with_env') as img:
      self.assertDigest(img, 'edf9048b897c285801c0d117c0c0f5b811dd5bc2ffc16d6c3111ced259cca49c')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [u'PATH=:/tmp/a:/tmp/b:/tmp/c', u'a=b', u'x=y'])

  def test_dummy_repository(self):
    # We allow users to specify an alternate repository name instead of 'bazel/'
    # to prefix their image names.
    name = 'gcr.io/dummy/%s:dummy_repository' % TEST_DATA_TARGET_BASE
    with TestBundleImage('dummy_repository', name) as img:
      self.assertDigest(img, '92e530f2a0bff100a2ca05d203829d55ccb158dc7f8c1160b603f0c4dc3fcd66')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_with_double_env(self):
    with TestImage('with_double_env') as img:
      self.assertDigest(img, 'fdd6551087ce110aa9c785d3ac06b450a781982e4f82ca458132a58663a29bb4')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [
        u'bar=blah blah blah',
        u'baz=/asdf blah blah blah',
        u'foo=/asdf'])

  def test_with_label(self):
    with TestImage('with_label') as img:
      self.assertDigest(img, '2fadf716112cedaffa0e1a31865b02e2006641a9ad2a20d8cc4ce484a91d0299')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        u'com.example.bar': u'{"name": "blah"}',
        u'com.example.baz': u'qux',
        u'com.example.foo': u'{"name": "blah"}',
      })

  def test_with_double_label(self):
    with TestImage('with_double_label') as img:
      self.assertDigest(img, '7ae45ba114e7eb95bce9ca4460b2b4ea31b99881ec21d81c2ff0f2caa8c58f5d')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        u'com.example.bar': u'{"name": "blah"}',
        u'com.example.baz': u'qux',
        u'com.example.foo': u'{"name": "blah"}',
        u'com.example.qux': u'{"name": "blah-blah"}',
      })

  def test_with_user(self):
    with TestImage('with_user') as img:
      self.assertDigest(img, '2a9eaa65d81953125e4c9f26c3704efac474b95c49a92e3232dff15218880eaf')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'User', 'nobody')

  def test_data_path(self):
    # Without data_path = "." the file will be inserted as `./test`
    # (since it is the path in the package) and with data_path = "."
    # the file will be inserted relatively to the testdata package
    # (so `./test/test`).
    with TestImage('no_data_path_image') as img:
      self.assertDigest(img, '4c2b4bba2e24b9f4132e0ee390410434d3bf072d15a0297265c9855243625523')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test'])
    with TestImage('data_path_image') as img:
      self.assertDigest(img, '9551977fc02ef927f39a4607a54923b53771f22e8a470eae85c69fc8fc31ebba')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test', './test/test'])

    # With an absolute path for data_path, we should strip that prefix
    # from the files' paths. Since the testdata images are in
    # //testdata and data_path is set to
    # "/tools/build_defs", we should have `docker` as the top-level
    # directory.
    with TestImage('absolute_data_path_image') as img:
      self.assertDigest(img, '09fc5c7a8c3f7c7b3a27f43886eea6912a546ff039175c1f0dab43d0dee97528')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])
      # With data_path = "/", we expect the entire path from the repository
      # root.
    with TestImage('root_data_path_image') as img:
      self.assertDigest(img, '09fc5c7a8c3f7c7b3a27f43886eea6912a546ff039175c1f0dab43d0dee97528')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])

  def test_flattened(self):
    with tarfile.open(TestData('flat.tar'), mode='r') as tar:
      self.assertTarballContains(tar, [
        '.', '/usr', '/usr/bin', '/usr/bin/java', './foo'])

  def test_bundle(self):
    with TestBundleImage('stamped_bundle_test', "example.com/aaaaa{BUILD_USER}:stamped".format(
        BUILD_USER=STAMP_DICT['BUILD_USER']
    )) as img:
        self.assertDigest(img, '2a9eaa65d81953125e4c9f26c3704efac474b95c49a92e3232dff15218880eaf')
    with TestBundleImage('bundle_test', 'docker.io/ubuntu:latest') as img:
      self.assertDigest(img, '55e9d4c0d06433ceb8b82c46075547c1a886788c508eb8f83f57f450b57c1bf9')
      self.assertEqual(1, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'us.gcr.io/google-appengine/base:fresh') as img:
      self.assertDigest(img, '6f0bf87b366dd307c0b26505c797cf3fe70e3e3706cf104ff43060b915a6f987')
      self.assertEqual(2, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'gcr.io/google-containers/pause:2.0') as img:
      self.assertDigest(img, 'fdd6551087ce110aa9c785d3ac06b450a781982e4f82ca458132a58663a29bb4')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_stamped_label(self):
    with TestImage('with_stamp_label') as img:
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {'BUILDER': STAMP_DICT['BUILD_USER']})

  def test_pause_based(self):
    with TestImage('pause_based') as img:
      self.assertDigest(img, '1a7dcda482673f76d50d50d35e7fc68e2cc4477c88051e1590d87e78f32e71eb')
      self.assertEqual(3, len(img.fs_layers()))

  def test_pause_piecemeal(self):
    with TestImage('pause_piecemeal/image') as img:
      self.assertDigest(img, 'ca362da80137d6e22de45cac9705271c694e63d87d4f98f1485288e83bda7334')
      self.assertEqual(2, len(img.fs_layers()))

  def test_pause_piecemeal_gz(self):
    with TestImage('pause_piecemeal_gz/image') as img:
      self.assertDigest(img, 'ca362da80137d6e22de45cac9705271c694e63d87d4f98f1485288e83bda7334')

  def test_build_with_tag(self):
    with TestBundleImage('build_with_tag', 'gcr.io/build/with:tag') as img:
      self.assertDigest(img, '76a3586a9b78b2570d87e0a5e82ebefc1f5f252df7e75532c5b541273096bd8f')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_passwd(self):
    with TestImage('with_passwd') as img:
      self.assertDigest(img, '86d8042be77e0603ff2888a351599abe34dfc40922ecc22bb78361bbd32c980b')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/passwd'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/passwd').read()
        self.assertEqual(
          'root:x:0:0:Root:/root:/rootshell\nfoobar:x:1234:2345:myusernameinfo:/myhomedir:/myshell\nnobody:x:65534:65534:nobody with no home:/nonexistent:/sbin/nologin\n',
          content)
        self.assertEqual(layer.getmember("./etc/passwd").mode, PASSWD_FILE_MODE)

  def test_with_passwd_tar(self):
    with TestImage('with_passwd_tar') as img:
      self.assertDigest(img, '7c621c0eed5d2713ca84b4e1e6d5fd017b886cf7697912dde7e4ba965574eb10')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/password', './root', './myhomedir'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/password').read()
        self.assertEqual(
          'root:x:0:0:Root:/root:/rootshell\nfoobar:x:1234:2345:myusernameinfo:/myhomedir:/myshell\nnobody:x:65534:65534:nobody with no home:/nonexistent:/sbin/nologin\n',
          content)
        self.assertEqual(layer.getmember("./etc/password").mode, PASSWD_FILE_MODE)
        self.assertTarInfo(layer.getmember("./root"), 0, 0, DIR_PERMISSION, True)
        self.assertTarInfo(layer.getmember("./myhomedir"), 1234, 2345, DIR_PERMISSION, True)


  def test_with_group(self):
    with TestImage('with_group') as img:
      self.assertDigest(img, 'ecab5d41beaeff5581912ba492e1b9e1db27f76f260c3fc64b2e8ab6286526e2')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/group'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/group').read()
        self.assertEqual('root:x:0:\nfoobar:x:2345:foo,bar,baz\n', content)

  def test_with_empty_files(self):
    with TestImage('with_empty_files') as img:
      self.assertDigest(img, '040de78d61acc42a084a342bdf43a3934af5522bb90e107daab66ba0a71126dd')
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
      self.assertDigest(img, '0a844b4de26cd7c0c5440aae327d3687fd6b8896d8d80fe1562b55c63263f128')
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
        './app/io_bazel_rules_docker',
        # TODO(mattmoor): The path normalization for symlinks should match
        # files to avoid this redundancy.
        '/app',
        '/app/testdata',
        '/app/testdata/py_image.binary',
        '/app/testdata/py_image.binary.runfiles',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/external',
      ])

      # Below that, we have a layer that generates symlinks for the library layer.
      self.assertLayerNContains(img, 1, [
        '.',
        '/app',
        '/app/testdata',
        '/app/testdata/py_image.binary.runfiles',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata',
        '/app/testdata/py_image.binary.runfiles/io_bazel_rules_docker/testdata/py_image_library.py',
      ])

      # Check the library layer, which is two below our application layer.
      self.assertLayerNContains(img, 2, [
        '.',
        './app',
        './app/io_bazel_rules_docker',
        './app/io_bazel_rules_docker/testdata',
        './app/io_bazel_rules_docker/testdata/py_image_library.py',
      ])

  def test_py_image_with_symlinks_in_data(self):
    with TestImage('py_image_with_symlinks_in_data') as img:
      # Check the application layer, which is on top.
      self.assertTopLayerContains(img, [
        '.',
        './app',
        './app/testdata',
        './app/testdata/py_image_with_symlinks_in_data.binary.runfiles',
        './app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker',
        './app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/testdata',
        './app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/testdata/py_image.py',
        './app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/testdata/py_image_with_symlinks_in_data.binary',
        './app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/testdata/foo.txt',
        './app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/testdata/__init__.py',
        './app/io_bazel_rules_docker',
        # TODO(mattmoor): The path normalization for symlinks should match
        # files to avoid this redundancy.
        '/app',
        '/app/testdata',
        '/app/testdata/py_image_with_symlinks_in_data.binary.runfiles',
        '/app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/foo-symlink.txt',
        '/app/testdata/py_image_with_symlinks_in_data.binary',
        '/app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/external',
      ])

      # Below that, we have a layer that generates symlinks for the library layer.
      self.assertLayerNContains(img, 1, [
        '.',
        '/app',
        '/app/testdata',
        '/app/testdata/py_image_with_symlinks_in_data.binary.runfiles',
        '/app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/testdata',
        '/app/testdata/py_image_with_symlinks_in_data.binary.runfiles/io_bazel_rules_docker/testdata/py_image_library.py',
      ])

      # Check the library layer, which is two below our application layer.
      self.assertLayerNContains(img, 2, [
        '.',
        './app',
        './app/io_bazel_rules_docker',
        './app/io_bazel_rules_docker/testdata',
        './app/io_bazel_rules_docker/testdata/py_image_library.py',
      ])

  def test_py_image_complex(self):
    with TestImage('py_image_complex') as img:
      # bazel-bin/testdata/py_image_complex-layer.tar
      self.assertTopLayerContains(img, [
        '.',
        './app',
        './app/testdata',
        './app/testdata/py_image_complex.binary.runfiles',
        './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker',
        './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata',
        './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/py_image_complex.py',
        './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/py_image_complex.binary',
        './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/test',
        './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/test/__init__.py',
        './app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0',
        './app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/__init__.py',
        './app/testdata/py_image_complex.binary.runfiles/__init__.py',
        './app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2',
        './app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/__init__.py',
        './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/__init__.py',
        './app/io_bazel_rules_docker',
        '/app',
        '/app/testdata',
        '/app/testdata/py_image_complex.binary',
        '/app/testdata/py_image_complex.binary.runfiles',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/external',
      ])

      # bazel-bin/testdata/py_image_complex.3-symlinks-layer.tar
      self.assertLayerNContains(img, 1, [
        '.',
        '/app',
        '/app/testdata',
        '/app/testdata/py_image_complex.binary.runfiles',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/py_image_complex_library.py',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/py_image_library_using_six.py',
      ])

      # bazel-bin/testdata/py_image_complex.3-layer.tar
      self.assertLayerNContains(img, 2, [
        '.',
        './app',
        './app/io_bazel_rules_docker',
        './app/io_bazel_rules_docker/testdata',
        './app/io_bazel_rules_docker/testdata/py_image_complex_library.py',
        './app/io_bazel_rules_docker/testdata/py_image_library_using_six.py',
      ])

      # bazel-bin/testdata/py_image_complex.2-symlinks-layer.tar
      self.assertLayerNContains(img, 3, [
        '.',
        '/app',
        '/app/testdata',
        '/app/testdata/py_image_complex.binary.runfiles',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/test',
        '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/test/py_image_library_using_addict.py',
      ])

      # bazel-bin/testdata/py_image_complex.2-layer.tar
      self.assertLayerNContains(img, 4, [
        '.',
        './app',
        './app/io_bazel_rules_docker',
        './app/io_bazel_rules_docker/testdata',
        './app/io_bazel_rules_docker/testdata/test',
        './app/io_bazel_rules_docker/testdata/test/py_image_library_using_addict.py',
      ])

      # bazel-bin/testdata/py_image_complex.1-symlinks-layer.tar
      self.assertLayerNContains(img, 5, [
        '.',
        '/app',
        '/app/testdata',
        '/app/testdata/py_image_complex.binary.runfiles',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/six.py',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/six-1.11.0.dist-info',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/six-1.11.0.dist-info/DESCRIPTION.rst',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/six-1.11.0.dist-info/METADATA',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/six-1.11.0.dist-info/RECORD',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/six-1.11.0.dist-info/WHEEL',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/six-1.11.0.dist-info/metadata.json',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__six_1_11_0/six-1.11.0.dist-info/top_level.txt',
      ])

      # bazel-bin/testdata/py_image_complex.1-layer.tar
      self.assertLayerNContains(img, 6, [
        '.',
        './app',
        './app/pypi__six_1_11_0',
        './app/pypi__six_1_11_0/six.py',
        './app/pypi__six_1_11_0/six-1.11.0.dist-info',
        './app/pypi__six_1_11_0/six-1.11.0.dist-info/DESCRIPTION.rst',
        './app/pypi__six_1_11_0/six-1.11.0.dist-info/METADATA',
        './app/pypi__six_1_11_0/six-1.11.0.dist-info/RECORD',
        './app/pypi__six_1_11_0/six-1.11.0.dist-info/WHEEL',
        './app/pypi__six_1_11_0/six-1.11.0.dist-info/metadata.json',
        './app/pypi__six_1_11_0/six-1.11.0.dist-info/top_level.txt',
      ])


      # bazel-bin/testdata/py_image_complex.0-symlinks-layer.tar
      self.assertLayerNContains(img, 7, [
        '.',
        '/app',
        '/app/testdata',
        '/app/testdata/py_image_complex.binary.runfiles',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict/__init__.py',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict/addict.py',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict-2.1.2.dist-info',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict-2.1.2.dist-info/DESCRIPTION.rst',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict-2.1.2.dist-info/METADATA',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict-2.1.2.dist-info/RECORD',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict-2.1.2.dist-info/WHEEL',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict-2.1.2.dist-info/metadata.json',
        '/app/testdata/py_image_complex.binary.runfiles/pypi__addict_2_1_2/addict-2.1.2.dist-info/top_level.txt',
      ])

      # bazel-bin/testdata/py_image_complex.0-layer.tar
      self.assertLayerNContains(img, 8, [
        '.',
        './app',
        './app/pypi__addict_2_1_2',
        './app/pypi__addict_2_1_2/addict',
        './app/pypi__addict_2_1_2/addict/__init__.py',
        './app/pypi__addict_2_1_2/addict/addict.py',
        './app/pypi__addict_2_1_2/addict-2.1.2.dist-info',
        './app/pypi__addict_2_1_2/addict-2.1.2.dist-info/DESCRIPTION.rst',
        './app/pypi__addict_2_1_2/addict-2.1.2.dist-info/METADATA',
        './app/pypi__addict_2_1_2/addict-2.1.2.dist-info/RECORD',
        './app/pypi__addict_2_1_2/addict-2.1.2.dist-info/WHEEL',
        './app/pypi__addict_2_1_2/addict-2.1.2.dist-info/metadata.json',
        './app/pypi__addict_2_1_2/addict-2.1.2.dist-info/top_level.txt',
      ])

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
        './app/io_bazel_rules_docker/testdata/BUILD',
        './app/io_bazel_rules_docker/testdata/java_image.classpath'
      ])

      self.assertLayerNContains(img, 1, [
        '.',
        './app',
        './app/io_bazel_rules_docker',
        './app/io_bazel_rules_docker/testdata',
        './app/io_bazel_rules_docker/testdata/libjava_image_library.jar',
        './app/com_google_guava_guava',
        './app/com_google_guava_guava/guava-18.0.jar',
      ])

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

  # Re-enable once https://github.com/bazelbuild/rules_d/issues/14 is fixed.
  # def test_d_image_args(self):
  #  with TestImage('d_image') as img:
  #    self.assertConfigEqual(img, 'Entrypoint', [
  #      '/app/testdata/d_image_binary',
  #      'arg0',
  #      'arg1'])

def load_stamp_info():
  stamp_file = TestData("stamp_info_file.txt")
  with open(stamp_file) as stamp_fp:
    for line in stamp_fp:
      # The first column in each line in the stamp file is the key
      # and the second column is the corresponding value.
      split_line = line.strip().split()
      if len(split_line) == 0:
        # Skip blank lines.
        continue
      key = ""
      value = ""
      if len(split_line) == 1:
        # Value is blank.
        key = split_line[0]
      else:
        key = split_line[0]
        value = " ".join(split_line[1:])
      STAMP_DICT[key] = value
      print("Stamp variable '{key}'='{value}'".format(
        key=key,
        value=value
      ))

if __name__ == '__main__':
  load_stamp_info()
  unittest.main()
