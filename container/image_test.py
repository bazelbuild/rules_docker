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

def TestRunfilePath(path):
  """Convert a path to a file target to the runfile path"""
  return os.path.join(os.environ['TEST_SRCDIR'], 'io_bazel_rules_docker', path)

def TestData(name):
  return TestRunfilePath(os.path.join(TEST_DATA_TARGET_BASE, name))

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
      self.assertDigest(img, '1d62b59d5148de83529891d20bbaab459d6d2d907f9e9fe601f12033adfc8eb2')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_files_with_file_base(self):
    with TestImage('files_with_files_base') as img:
      self.assertDigest(img, '663959daa657db3c5514ccca71ad19ef58dacea1c6c4c0c4e22350afa812bcaf')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_files_in_layer_with_file_base(self):
    with TestImage('files_in_layer_with_files_base') as img:
      self.assertDigest(img, '7847e90b5b59366125eaf7d5924d8753552c2d546d72d61a6686e552bcf2c896')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertLayerNContains(img, 2, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './baz'])
      self.assertLayerNContains(img, 0, ['.', './bar'])

  def test_tar_base(self):
    with TestImage('tar_base') as img:
      self.assertDigest(img, '882f98422db36b0f1ff5535c8b085c541634a12c104676a0815f3bd68075bca4')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './usr', './usr/bin', './usr/bin/unremarkabledeath'])
      # Check that this doesn't have a configured entrypoint.
      self.assertConfigEqual(img, 'Entrypoint', None)

  def test_tar_with_tar_base(self):
    with TestImage('tar_with_tar_base') as img:
      self.assertDigest(img, '1c9876ed89f199015b8781f576c565ac9fbb7a180aac509891a5ba67ea6b30be')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_tars_in_layer_with_tar_base(self):
    with TestImage('tars_in_layer_with_tar_base') as img:
      self.assertDigest(img, 'd8c029b5b3c735ed3c4a1418e25422a467976fe81908dd116765ec4fdfb8e6d7')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, [
          './usr', './usr/bin', './usr/bin/unremarkabledeath'])

  def test_directory_with_tar_base(self):
    with TestImage('directory_with_tar_base') as img:
      self.assertDigest(img, '201cf477701537f8dfe9c36c21ed4ef42221bc31359623d8101ab8515f918a1f')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './foo', './foo/asdf', './foo/usr',
        './foo/usr/bin', './foo/usr/bin/miraclegrow'])

  def test_files_with_tar_base(self):
    with TestImage('files_with_tar_base') as img:
      self.assertDigest(img, 'c124a38342aca13578834a3e5ac0ff3a8105b09f91ac230e23eb568edc5bb59b')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_workdir_with_tar_base(self):
    with TestImage('workdir_with_tar_base') as img:
      self.assertDigest(img, 'f36dee90974e6669c00694efc21ee05ac930f9f90c95a94d5e87137f10cd909b')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [])
      # Check that the working directory property has been properly configured.
      self.assertConfigEqual(img, 'WorkingDir', '/tmp')

  def test_tar_with_files_base(self):
    with TestImage('tar_with_files_base') as img:
      self.assertDigest(img, '727dd95ad27c05331c3b4df6e28604815e0870165dce9f66f25c5c4c6b94319c')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_docker_tarball_base(self):
    with TestImage('docker_tarball_base') as img:
      self.assertDigest(img, '497da624de028b9e7b8c40de2ab89b2ad52a9cc266d804bbdfb108532aa1bca8')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_layers_with_docker_tarball_base(self):
    with TestImage('layers_with_docker_tarball_base') as img:
      self.assertDigest(img, 'ebcce6c0dd4a62f7cbade41e3a20372230c8f66d4609e132ae0bb7c739ffbb8a')
      self.assertEqual(5, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, ['.', './baz'])

  def test_base_with_entrypoint(self):
    with TestImage('base_with_entrypoint') as img:
      self.assertDigest(img, 'f9c36390f068fe22bc26fe4348c1ec654e686de767b30df63719b5ed84c1df19')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'ExposedPorts', {'8080/tcp': {}})

  def test_dashdash_entrypoint(self):
    with TestImage('dashdash_entrypoint') as img:
      self.assertDigest(img, '4a8a8ce2d77129d22b8386daf6f62be9e86cd8908542aee18120bc8ff2abb626')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar', '--'])

  def test_derivative_with_cmd(self):
    with TestImage('derivative_with_cmd') as img:
      self.assertDigest(img, '28fdfb929a22d7660f67cdf9e3a17eb9bb5325ac99335acc5c4c9d27d62727e4')
      self.assertEqual(3, len(img.fs_layers()))

      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'Cmd', ['arg1', 'arg2'])
      self.assertConfigEqual(
        img, 'ExposedPorts', {'8080/tcp': {}, '80/tcp': {}})

  def test_derivative_with_volume(self):
    with TestImage('derivative_with_volume') as img:
      self.assertDigest(img, '9929dab88d5a8d51678d33d1b186c9abf08fbd307fd68ea1644f99e324ca35ea')
      self.assertEqual(2, len(img.fs_layers()))

      # Check that the topmost layer has the volumes exposed by the bottom
      # layer, and itself.
      self.assertConfigEqual(img, 'Volumes', {
        '/asdf': {}, '/blah': {}, '/logs': {}
      })

  def test_with_unix_epoch_creation_time(self):
    with TestImage('with_unix_epoch_creation_time') as img:
      self.assertDigest(img, '692d305823a8736e33efbe463c8ef4946fb944efdc7d1dc3621fd8fade3ff56e')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('2009-02-13T23:31:30.119999885Z', cfg.get('created', ''))

  def test_with_millisecond_unix_epoch_creation_time(self):
    with TestImage('with_millisecond_unix_epoch_creation_time') as img:
      self.assertDigest(img, 'e3633f83aede25b03697cd0736c3cf80a0a28daf57b196543dd06cf6a5ab98b4')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('2009-02-13T23:31:30.12345004Z', cfg.get('created', ''))

  def test_with_rfc_3339_creation_time(self):
    with TestImage('with_rfc_3339_creation_time') as img:
      self.assertDigest(img, '6205c92a6477b7d6986f4dff267500ec84086258889545b4f25607af04f56f0b')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('1989-05-03T12:58:12.345Z', cfg.get('created', ''))

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
      self.assertDigest(img, 'd79563f1ece830aba31e50a038dbc5488a925266d26295bffe3c4331ee54da1c')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', ['bar=blah blah blah', 'foo=/asdf'])

  def test_layers_with_env(self):
    with TestImage('layers_with_env') as img:
      self.assertDigest(img, '7d9695fede51782d36b08ea90d27f0aca8eb25a6cb723e60aa5bcd940936e718')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [u'PATH=$PATH:/tmp/a:/tmp/b:/tmp/c', u'a=b', u'x=y'])

  def test_dummy_repository(self):
    # We allow users to specify an alternate repository name instead of 'bazel/'
    # to prefix their image names.
    name = 'gcr.io/dummy/%s:dummy_repository' % TEST_DATA_TARGET_BASE
    with TestBundleImage('dummy_repository', name) as img:
      self.assertDigest(img, 'a3eebb4b8da904a659f76e8e411add48641abb611e63820f4d0726bf3b8570b6')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_with_double_env(self):
    with TestImage('with_double_env') as img:
      self.assertDigest(img, '1221ba0aacbf4c3ee5831354bbbe7ec9dd9a0029fa562909bd8fa2db2c40dbd6')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [
        'bar=blah blah blah',
        'baz=/asdf blah blah blah',
        'foo=/asdf'])

  def test_with_label(self):
    with TestImage('with_label') as img:
      self.assertDigest(img, 'ff712f14eaa870941a4f5bf6744e394db902cf03e4df5cd443f107b95cc4ba26')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        'com.example.bar': '{"name": "blah"}',
        'com.example.baz': 'qux',
        'com.example.foo': '{"name": "blah"}',
      })

  def test_with_double_label(self):
    with TestImage('with_double_label') as img:
      self.assertDigest(img, '653ab1fec0084a9b4827a128fe35e6dbcf0953ef99748b47619131751fe25ebc')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        'com.example.bar': '{"name": "blah"}',
        'com.example.baz': 'qux',
        'com.example.foo': '{"name": "blah"}',
        'com.example.qux': '{"name": "blah-blah"}',
      })

  def test_with_user(self):
    with TestImage('with_user') as img:
      self.assertDigest(img, '0d94630809cbfcb9c6478e14f83a0bd5cceb8c8d9cabc3b4b180ac55c7b7da2c')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'User', 'nobody')

  def test_data_path(self):
    # Without data_path = "." the file will be inserted as `./test`
    # (since it is the path in the package) and with data_path = "."
    # the file will be inserted relatively to the testdata package
    # (so `./test/test`).
    with TestImage('no_data_path_image') as img:
      self.assertDigest(img, '0dc6634f90911dfa6ff368135ea2d13ae4136a16cfc6c2d00f62d1fe949ea333')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test'])
    with TestImage('data_path_image') as img:
      self.assertDigest(img, '21dfb114bca23f4615b93c64ee5ac2e3187870e446cb0225dcb357302e33e1b2')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test', './test/test'])

    # With an absolute path for data_path, we should strip that prefix
    # from the files' paths. Since the testdata images are in
    # //testdata and data_path is set to
    # "/tools/build_defs", we should have `docker` as the top-level
    # directory.
    with TestImage('absolute_data_path_image') as img:
      self.assertDigest(img, '54769a89c86321d6daf162ce0dedf2c9b457c1c773e9bcc27bb6b221c16550e5')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])
      # With data_path = "/", we expect the entire path from the repository
      # root.
    with TestImage('root_data_path_image') as img:
      self.assertDigest(img, '54769a89c86321d6daf162ce0dedf2c9b457c1c773e9bcc27bb6b221c16550e5')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])

  def test_flattened(self):
    # Test the flattened tarball produced by the python flattener
    # binary from google/containerregistry.
    with tarfile.open(TestData('flat.tar'), mode='r') as tar:
      self.assertTarballContains(tar, [
        '.', '/usr', '/usr/bin', '/usr/bin/java', './foo'])

  def test_flattened_go(self):
    # Test the flattened tarball produced by the Go flattener binary.
    with tarfile.open(TestData('flat_go.tar'), mode='r') as tar:
      self.assertTarballContains(tar, [
        '.', '/usr', '/usr/bin', '/usr/bin/java', './foo'])

  def test_flattened_from_tarball_base(self):
    # Test the flattened tarball produced by the Go flattener where the
    # image being flattened derived from an image specified as a tarball.
    # File "bar" came from the base image specified as a tarball and "baz"
    # came from the top level image.
    with tarfile.open(TestData('flatten_with_tarball_base.tar'), mode='r') as tar:
      self.assertTarballContains(tar, [
        '.', './baz', './bar',])

  def test_bundle(self):
    with TestBundleImage('stamped_bundle_test', "example.com/aaaaa{BUILD_USER}:stamped".format(
        BUILD_USER=STAMP_DICT['BUILD_USER']
    )) as img:
        self.assertDigest(img, '0d94630809cbfcb9c6478e14f83a0bd5cceb8c8d9cabc3b4b180ac55c7b7da2c')
    with TestBundleImage('bundle_test', 'docker.io/ubuntu:latest') as img:
      self.assertDigest(img, 'f9c36390f068fe22bc26fe4348c1ec654e686de767b30df63719b5ed84c1df19')
      self.assertEqual(1, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'us.gcr.io/google-appengine/base:fresh') as img:
      self.assertDigest(img, 'fa1d816340ea2b89fe174edc13f5b4e5f26f069aa392ec782fff30568cc092cb')
      self.assertEqual(2, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'gcr.io/google-containers/pause:2.0') as img:
      self.assertDigest(img, '1221ba0aacbf4c3ee5831354bbbe7ec9dd9a0029fa562909bd8fa2db2c40dbd6')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_stamped_label(self):
    with TestImage('with_stamp_label') as img:
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {'BUILDER': STAMP_DICT['BUILD_USER']})

  def test_pause_based(self):
    with TestImage('pause_based') as img:
      self.assertDigest(img, '3ade3b396cd3a2517ad202e4f840b5bbb8c69558622059be48ff02a9ec1b4f1e')
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
      self.assertDigest(img, '78dd776b7c25bc6f79ec898a875aaa070c5b54be746b3f30bf9af1f7830b4b67')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_passwd(self):
    with TestImage('with_passwd') as img:
      self.assertDigest(img, 'd4c2d7ed264877c09fd9b6b040486a710aad0b7e5586ccc9efab5fb5d0772c48')
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
      self.assertDigest(img, '6732c72d50b1a0ec521588cf26f5ceb84ae4fd9b31558409293449d9d37fad6d')
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
      self.assertDigest(img, '262961fb06c25bdd658ed34454f944c8baaa8f40f54b2bea3b4e3ffff3a16449')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/group'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/group').read()
        self.assertEqual('root:x:0:\nfoobar:x:2345:foo,bar,baz\n', content)

  def test_with_empty_files(self):
    with TestImage('with_empty_files') as img:
      self.assertDigest(img, '0c7ddfa4c797219b23ac377a07a16ecac28881151483b02040c16f0569c11cdc')
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
      self.assertDigest(img, '4b131d8dcc456c6e9b87162f7167251ea8cc45cced3db91b038693b781de987d')
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

  def test_windows_image_manifest_with_foreign_layers(self):
    imgPath = TestRunfilePath("tests/container/basic_windows_image_go_join_layers.tar")
    with v2_2_image.FromTarball(imgPath) as img:
      # Ensure the image manifest in the tarball includes the foreign layer.
      self.assertIn("https://go.microsoft.com/fwlink/?linkid=873595",
        img.manifest())

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
