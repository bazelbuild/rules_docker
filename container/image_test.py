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
      self.assertDigest(img, 'b2042de8d0d7f2cd89328f22ba4f9e4884d1ea7385e3b1ec8ae686c1cf8377de')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_files_with_file_base(self):
    with TestImage('files_with_files_base') as img:
      self.assertDigest(img, 'cefcefed03f1a69abb8e615979a8214a8f2cf257713b1aa8a9d3e4c3314fcfda')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_files_in_layer_with_file_base(self):
    with TestImage('files_in_layer_with_files_base') as img:
      self.assertDigest(img, 'cc4da646e3123052bb5ddf1e7c1ff1fa9e473691b2876f859ab53d294502dbbc')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertLayerNContains(img, 2, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './baz'])
      self.assertLayerNContains(img, 0, ['.', './bar'])

  def test_tar_base(self):
    with TestImage('tar_base') as img:
      self.assertDigest(img, '611270a900f1d95f896af3d8c38ff04f75d75f972c02eab0403aa12847881489')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './usr', './usr/bin', './usr/bin/unremarkabledeath'])
      # Check that this doesn't have a configured entrypoint.
      self.assertConfigEqual(img, 'Entrypoint', None)

  def test_tar_with_tar_base(self):
    with TestImage('tar_with_tar_base') as img:
      self.assertDigest(img, '07a2a6a8547551b318b525cf3388a5515060d3cc4354657b8b2e84c8ea6105c9')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_tars_in_layer_with_tar_base(self):
    with TestImage('tars_in_layer_with_tar_base') as img:
      self.assertDigest(img, 'feb6575d686ca8dc96015322c120f786baaa3509d5795ad2d43b9302433f297e')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, [
          './usr', './usr/bin', './usr/bin/unremarkabledeath'])

  def test_directory_with_tar_base(self):
    with TestImage('directory_with_tar_base') as img:
      self.assertDigest(img, 'c81286d84de3bd284b517de070f2813233fb296143acfb3724cca2558bd44086')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './foo', './foo/asdf', './foo/usr',
        './foo/usr/bin', './foo/usr/bin/miraclegrow'])

  def test_files_with_tar_base(self):
    with TestImage('files_with_tar_base') as img:
      self.assertDigest(img, 'ea1dd1fd76aea45ce08573b80202408af40c05c4091a558b5e90ba2785d875aa')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_workdir_with_tar_base(self):
    with TestImage('workdir_with_tar_base') as img:
      self.assertDigest(img, 'c3b1757b19e007ae28cb456daa6bc0d37531804e750ef3d22ac20f29f2b76aa4')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [])
      # Check that the working directory property has been properly configured.
      self.assertConfigEqual(img, 'WorkingDir', '/tmp')

  def test_tar_with_files_base(self):
    with TestImage('tar_with_files_base') as img:
      self.assertDigest(img, '9f11c380bd9d72b9be0c0e6369705e8b13b70e2af70a8f7bf1584c0580bcb63e')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_docker_tarball_base(self):
    with TestImage('docker_tarball_base') as img:
      self.assertDigest(img, '5ef26612cc7c3a7d62580c97cc75f0507bb89142ffd36f5f172ddb7f0874bed6')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_layers_with_docker_tarball_base(self):
    with TestImage('layers_with_docker_tarball_base') as img:
      self.assertDigest(img, '0d6ae1aa69ff75c0d985619d73bc06b05669835a9300a799aa68392e5f92b983')
      self.assertEqual(5, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, ['.', './baz'])

  def test_base_with_entrypoint(self):
    with TestImage('base_with_entrypoint') as img:
      self.assertDigest(img, '2b4114ac954ad863da264deb69586f43dd6ff1cb937c057cd11771b361436f73')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'ExposedPorts', {'8080/tcp': {}})

  def test_dashdash_entrypoint(self):
    with TestImage('dashdash_entrypoint') as img:
      self.assertDigest(img, '921b63580668951c8d1444cd419eecaf64b4a86c86de9a8f657f863201d15962')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar', '--'])

  def test_derivative_with_cmd(self):
    with TestImage('derivative_with_cmd') as img:
      self.assertDigest(img, '709e155a071ea177fad8ae737ab405124a859d6a7c81c0ee868dccc8d27ae314')
      self.assertEqual(3, len(img.fs_layers()))

      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'Cmd', ['arg1', 'arg2'])
      self.assertConfigEqual(
        img, 'ExposedPorts', {'8080/tcp': {}, '80/tcp': {}})

  def test_derivative_with_volume(self):
    with TestImage('derivative_with_volume') as img:
      self.assertDigest(img, '81a41ba96bbea5e22f1b733036a03d7fa8fa9535000e9c2570e17776eb6391b5')
      self.assertEqual(2, len(img.fs_layers()))

      # Check that the topmost layer has the volumes exposed by the bottom
      # layer, and itself.
      self.assertConfigEqual(img, 'Volumes', {
        '/asdf': {}, '/blah': {}, '/logs': {}
      })

  def test_with_unix_epoch_creation_time(self):
    with TestImage('with_unix_epoch_creation_time') as img:
      self.assertDigest(img, '4caeac4da61c673a93e0b0b28bf48c41c5774af1bcb015bc208bf3cd90073a94')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('2009-02-13T23:31:30.119999885Z', cfg.get('created', ''))

  def test_with_millisecond_unix_epoch_creation_time(self):
    with TestImage('with_millisecond_unix_epoch_creation_time') as img:
      self.assertDigest(img, '6d916ca2fb6eedef06349f9947a637f65ee6d30ae1bc72e23946986a3cf2c943')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('2009-02-13T23:31:30.12345004Z', cfg.get('created', ''))

  def test_with_rfc_3339_creation_time(self):
    with TestImage('with_rfc_3339_creation_time') as img:
      self.assertDigest(img, '2180a9e316d3aeeb967424104489d41d16917f4b32713c47e7c0764a9596c2e7')
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
      self.assertDigest(img, 'f9e4654485168d82981351dabb479f456fd0ce58515efc738e0c3a58c4e510a5')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', ['bar=blah blah blah', 'foo=/asdf'])

  def test_layers_with_env(self):
    with TestImage('layers_with_env') as img:
      self.assertDigest(img, 'a6b386fc6a6fc9590759499e97d996e0a6541dc307501d8ac0f37a26e2053896')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [u'PATH=$PATH:/tmp/a:/tmp/b:/tmp/c', u'a=b', u'x=y'])

  def test_dummy_repository(self):
    # We allow users to specify an alternate repository name instead of 'bazel/'
    # to prefix their image names.
    name = 'gcr.io/dummy/%s:dummy_repository' % TEST_DATA_TARGET_BASE
    with TestBundleImage('dummy_repository', name) as img:
      self.assertDigest(img, 'b31fcce6cd0a451dccb1f9427d69907903eef6dba2de3ef7dc91c9c40c432b96')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_with_double_env(self):
    with TestImage('with_double_env') as img:
      self.assertDigest(img, '8d98c4f1241e197e8c902b65196d65ba61ffc3a39ac041dbad21f0f7d8978cd3')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [
        'bar=blah blah blah',
        'baz=/asdf blah blah blah',
        'foo=/asdf'])

  def test_with_label(self):
    with TestImage('with_label') as img:
      self.assertDigest(img, 'dca97e74a1717e81cdcdef0d7ef94e754eb3404cf52bbf61f32256e0bdd0162e')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        'com.example.bar': '{"name": "blah"}',
        'com.example.baz': 'qux',
        'com.example.foo': '{"name": "blah"}',
      })

  def test_with_double_label(self):
    with TestImage('with_double_label') as img:
      self.assertDigest(img, '74753b3f7beb9590e3df22a91c27bd658e85717e740b55c7d754860def1ff57c')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        'com.example.bar': '{"name": "blah"}',
        'com.example.baz': 'qux',
        'com.example.foo': '{"name": "blah"}',
        'com.example.qux': '{"name": "blah-blah"}',
      })

  def test_with_user(self):
    with TestImage('with_user') as img:
      self.assertDigest(img, '8d6a7bc0542324744200c2d09d18b54497d2e3e90ba1383c5b4ccae88b8cdf45')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'User', 'nobody')

  def test_data_path(self):
    # Without data_path = "." the file will be inserted as `./test`
    # (since it is the path in the package) and with data_path = "."
    # the file will be inserted relatively to the testdata package
    # (so `./test/test`).
    with TestImage('no_data_path_image') as img:
      self.assertDigest(img, '2ffc012948f2d6a4398d02c790248b65871c3900b9c33bd6399796ef3f14d5d3')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test'])
    with TestImage('data_path_image') as img:
      self.assertDigest(img, '127bc5b422c092f70821cd48b5b640a19e7c31fc4498de03ae59ef38cf258b7a')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test', './test/test'])

    # With an absolute path for data_path, we should strip that prefix
    # from the files' paths. Since the testdata images are in
    # //testdata and data_path is set to
    # "/tools/build_defs", we should have `docker` as the top-level
    # directory.
    with TestImage('absolute_data_path_image') as img:
      self.assertDigest(img, '22d7b915dbb69f2106a1e6d71a0097ec0c8d1581239243cf05eb9834ee77b74e')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])
      # With data_path = "/", we expect the entire path from the repository
      # root.
    with TestImage('root_data_path_image') as img:
      self.assertDigest(img, '22d7b915dbb69f2106a1e6d71a0097ec0c8d1581239243cf05eb9834ee77b74e')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])

  def test_flattened(self):
    # Test the flattened tarball produced by the python flattener
    # binary from google/containerregistry.
    with tarfile.open(TestData('flat.tar'), mode='r') as tar:
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
        self.assertDigest(img, '8d6a7bc0542324744200c2d09d18b54497d2e3e90ba1383c5b4ccae88b8cdf45')
    with TestBundleImage('bundle_test', 'docker.io/ubuntu:latest') as img:
      self.assertDigest(img, '2b4114ac954ad863da264deb69586f43dd6ff1cb937c057cd11771b361436f73')
      self.assertEqual(1, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'us.gcr.io/google-appengine/base:fresh') as img:
      self.assertDigest(img, '1f22478c091a41030c6703a01a870f2e312e9d759293a041b8fe6555da65b4df')
      self.assertEqual(2, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'gcr.io/google-containers/pause:2.0') as img:
      self.assertDigest(img, '8d98c4f1241e197e8c902b65196d65ba61ffc3a39ac041dbad21f0f7d8978cd3')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_stamped_label(self):
    with TestImage('with_stamp_label') as img:
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {'BUILDER': STAMP_DICT['BUILD_USER']})

  def test_pause_based(self):
    with TestImage('pause_based') as img:
      self.assertDigest(img, '1bb22dfaf26c6f68603c173e711739baceed82178ac33cc139207b323e65d641')
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
      self.assertDigest(img, '9be7bf7711df1a42a16536243fc88ad42269fd1b6027b1cca2049a44bbd5a08f')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_passwd(self):
    with TestImage('with_passwd') as img:
      self.assertDigest(img, '2d9d8c80f8583bfcc5276835836f01682e49abead17c5a4dab7293b019943545')
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
      self.assertDigest(img, 'b7a3e3ea93db1cb8068aa1cbaf11f9b771c33eb4d220abe87fe140d1260b17d2')
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
      self.assertDigest(img, '606b33644870f6b50d6675a6c717c028bde28c64ec6c004c46a23d4d65b2216a')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/group'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/group').read()
        self.assertEqual('root:x:0:\nfoobar:x:2345:foo,bar,baz\n', content)

  def test_with_empty_files(self):
    with TestImage('with_empty_files') as img:
      self.assertDigest(img, '6d1633a12c4e7eb5e1e0fcafeb0072cdd17b522f5e0d40ff2dc333fd90e43060')
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
      self.assertDigest(img, '7ec825dfcd225c6e419309855f4b60b3af91ce95617ef9fc79e36e009c54f85a')
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
    imgPath = TestRunfilePath("tests/container/basic_windows_image.tar")
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
