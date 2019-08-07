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
      self.assertDigest(img, '57011d344ceb6efb3cfab13d66e9439404a57c24798fb659674f2e0db4febb10')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_files_with_file_base(self):
    with TestImage('files_with_files_base') as img:
      self.assertDigest(img, '6287765dd80323b43e09f190857cbb79c0f52e7769cc9c048944ef5151398ff6')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_files_in_layer_with_file_base(self):
    with TestImage('files_in_layer_with_files_base') as img:
      self.assertDigest(img, 'a30d8758fdc2d296ac7f265f5cd0a79cb093a99ae5ea2c949c6c7297d2ac5ea8')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertLayerNContains(img, 2, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './baz'])
      self.assertLayerNContains(img, 0, ['.', './bar'])

  def test_tar_base(self):
    with TestImage('tar_base') as img:
      self.assertDigest(img, '4cee5a7409a9534dd1999e980be1a6b540bcd03fa10463031b5cb07c09bdcb31')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './usr', './usr/bin', './usr/bin/unremarkabledeath'])
      # Check that this doesn't have a configured entrypoint.
      self.assertConfigEqual(img, 'Entrypoint', None)

  def test_tar_with_tar_base(self):
    with TestImage('tar_with_tar_base') as img:
      self.assertDigest(img, '2befbaf4a45313bcb720eca722aa012add97bf922ea10c7da9e0db9401e71207')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_tars_in_layer_with_tar_base(self):
    with TestImage('tars_in_layer_with_tar_base') as img:
      self.assertDigest(img, '347bcc273ae83c8a031a2f71b502944b0dda5d56b4580bce767cf06ee9173cef')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, [
          './usr', './usr/bin', './usr/bin/unremarkabledeath'])

  def test_directory_with_tar_base(self):
    with TestImage('directory_with_tar_base') as img:
      self.assertDigest(img, '819ab0a36339b6d7d62f665ec9b1da81180f1607e9d452259583f426674bb4c4')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './foo', './foo/asdf', './foo/usr',
        './foo/usr/bin', './foo/usr/bin/miraclegrow'])

  def test_files_with_tar_base(self):
    with TestImage('files_with_tar_base') as img:
      self.assertDigest(img, '0f8e722de1728e85b21c253d096731adc8803cfb23eb8d1ff855a974f4b329d8')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_workdir_with_tar_base(self):
    with TestImage('workdir_with_tar_base') as img:
      self.assertDigest(img, 'bfda708904b0f6ef32f2e5e2ead8b6c6d283cacf68464f8fd99368af329740f2')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [])
      # Check that the working directory property has been properly configured.
      self.assertConfigEqual(img, 'WorkingDir', '/tmp')

  def test_tar_with_files_base(self):
    with TestImage('tar_with_files_base') as img:
      self.assertDigest(img, 'e955df26123a7f021fb8a9859eccac1aa308a26cd38b71b404d6085caa271c42')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_docker_tarball_base(self):
    with TestImage('docker_tarball_base') as img:
      self.assertDigest(img, 'c24e1086cd4826ee936da1c4d70d059f61349243ae6454ffbc73689bbc3b0ba7')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_layers_with_docker_tarball_base(self):
    with TestImage('layers_with_docker_tarball_base') as img:
      self.assertDigest(img, 'd32a107e3fc5b88c2b11227da73d067282bd03253ab1e31bb22fd6029daae91b')
      self.assertEqual(5, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, ['.', './baz'])

  def test_base_with_entrypoint(self):
    with TestImage('base_with_entrypoint') as img:
      self.assertDigest(img, '7743ce94e6670785937c49d29346ceb323fe64428ef17ffdf10ab64def527cdf')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'ExposedPorts', {'8080/tcp': {}})

  def test_dashdash_entrypoint(self):
    with TestImage('dashdash_entrypoint') as img:
      self.assertDigest(img, 'c6c4b0ccec57daee3fda4fb8fc2979b1a991feabea57952d581b31e308aec311')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar', '--'])

  def test_derivative_with_cmd(self):
    with TestImage('derivative_with_cmd') as img:
      self.assertDigest(img, '33c71da023a8b4c2981e0d2a111587c2a44052f262c8b6fda57ad4d6222791b1')
      self.assertEqual(3, len(img.fs_layers()))

      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'Cmd', ['arg1', 'arg2'])
      self.assertConfigEqual(
        img, 'ExposedPorts', {'8080/tcp': {}, '80/tcp': {}})

  def test_derivative_with_volume(self):
    with TestImage('derivative_with_volume') as img:
      self.assertDigest(img, '604baf693ffbe5cd4a2c1dc7e53a8d8035fbef6e494543cb1ee39e79c4959ef2')
      self.assertEqual(2, len(img.fs_layers()))

      # Check that the topmost layer has the volumes exposed by the bottom
      # layer, and itself.
      self.assertConfigEqual(img, 'Volumes', {
        '/asdf': {}, '/blah': {}, '/logs': {}
      })

  def test_with_unix_epoch_creation_time(self):
    with TestImage('with_unix_epoch_creation_time') as img:
      self.assertDigest(img, '12b475b961c93752d4db37f442c68a4aff46d6556cd3c22e23c324a6a288f4cd')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual(u'2009-02-13T23:31:30.119999885Z', cfg.get('created', ''))

  def test_with_millisecond_unix_epoch_creation_time(self):
    with TestImage('with_millisecond_unix_epoch_creation_time') as img:
      self.assertDigest(img, '53528bcd6ba9810dc460cc72cfe61e119f52c90b42d350b13378b727985de3d7')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual(u'2009-02-13T23:31:30.12345004Z', cfg.get('created', ''))

  def test_with_rfc_3339_creation_time(self):
    with TestImage('with_rfc_3339_creation_time') as img:
      self.assertDigest(img, '0a8dc32b1f208ab94522c166d5e79ff06a5b6ba8764b04962bf20f1dcf4b88f2')
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
      self.assertDigest(img, 'a444f205163d120f88cc1d58d88a25639256ddba0f6c3d8231afa97965d8b223')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [u'bar=blah blah blah', u'foo=/asdf'])

  def test_layers_with_env(self):
    with TestImage('layers_with_env') as img:
      self.assertDigest(img, 'c533cd7ed1c10dffae42a810c9c3192748bf47e272b3f18d90a730657723c759')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [u'PATH=:/tmp/a:/tmp/b:/tmp/c', u'a=b', u'x=y'])

  def test_dummy_repository(self):
    # We allow users to specify an alternate repository name instead of 'bazel/'
    # to prefix their image names.
    name = 'gcr.io/dummy/%s:dummy_repository' % TEST_DATA_TARGET_BASE
    with TestBundleImage('dummy_repository', name) as img:
      self.assertDigest(img, 'c6e89b7075553f4c0a85cb5661dc3e5f80359e80ea2269ecb005830480b52b9e')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_with_double_env(self):
    with TestImage('with_double_env') as img:
      self.assertDigest(img, '484a36e32d12cc5a8213f9ce024796d40aec6e2421722ba1010bf31a5c51aecc')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [
        u'bar=blah blah blah',
        u'baz=/asdf blah blah blah',
        u'foo=/asdf'])

  def test_with_label(self):
    with TestImage('with_label') as img:
      self.assertDigest(img, '1780859a1a8adefd40dc34a90ddaa5061da5b1f2b0f4046388b2d024a6b51c96')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        u'com.example.bar': u'{"name": "blah"}',
        u'com.example.baz': u'qux',
        u'com.example.foo': u'{"name": "blah"}',
      })

  def test_with_double_label(self):
    with TestImage('with_double_label') as img:
      self.assertDigest(img, '47080d2318843196e0a4f871197c3761d50e5e92ff34ced8f82303f34d95cfa4')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        u'com.example.bar': u'{"name": "blah"}',
        u'com.example.baz': u'qux',
        u'com.example.foo': u'{"name": "blah"}',
        u'com.example.qux': u'{"name": "blah-blah"}',
      })

  def test_with_user(self):
    with TestImage('with_user') as img:
      self.assertDigest(img, '742221f6d082c39212addf141d14008e93907ad0eb98809dfcdb94239defda73')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'User', 'nobody')

  def test_data_path(self):
    # Without data_path = "." the file will be inserted as `./test`
    # (since it is the path in the package) and with data_path = "."
    # the file will be inserted relatively to the testdata package
    # (so `./test/test`).
    with TestImage('no_data_path_image') as img:
      self.assertDigest(img, 'c80abaa97ae7054d5a77f9117713209a373a4a8e70fdda5a05dd8ac8c6ea90ea')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test'])
    with TestImage('data_path_image') as img:
      self.assertDigest(img, '530ae0bf908c8ba93541173ea7782272033bdcdc0189eb871022f4a756266560')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test', './test/test'])

    # With an absolute path for data_path, we should strip that prefix
    # from the files' paths. Since the testdata images are in
    # //testdata and data_path is set to
    # "/tools/build_defs", we should have `docker` as the top-level
    # directory.
    with TestImage('absolute_data_path_image') as img:
      self.assertDigest(img, '3a69b46caf6c5d69de5dc074c313956cd25b00e576b7be376704001720485fa0')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])
      # With data_path = "/", we expect the entire path from the repository
      # root.
    with TestImage('root_data_path_image') as img:
      self.assertDigest(img, '3a69b46caf6c5d69de5dc074c313956cd25b00e576b7be376704001720485fa0')
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
        self.assertDigest(img, '742221f6d082c39212addf141d14008e93907ad0eb98809dfcdb94239defda73')
    with TestBundleImage('bundle_test', 'docker.io/ubuntu:latest') as img:
      self.assertDigest(img, '7743ce94e6670785937c49d29346ceb323fe64428ef17ffdf10ab64def527cdf')
      self.assertEqual(1, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'us.gcr.io/google-appengine/base:fresh') as img:
      self.assertDigest(img, '9ccaf1d9509e82da49bc3f503e5b1638005fc21cb17561a03c4374bae89db685')
      self.assertEqual(2, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'gcr.io/google-containers/pause:2.0') as img:
      self.assertDigest(img, '484a36e32d12cc5a8213f9ce024796d40aec6e2421722ba1010bf31a5c51aecc')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_stamped_label(self):
    with TestImage('with_stamp_label') as img:
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {'BUILDER': STAMP_DICT['BUILD_USER']})

  def test_pause_based(self):
    with TestImage('pause_based') as img:
      self.assertDigest(img, '917a6af5003f5d7da23249eff4b82dbcd66df509265651711be508b74937e34e')
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
      self.assertDigest(img, 'ed8006546b6e1168305479b7ddb4a18235b769f7c13d387aa8b5e4838d2d8bc8')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_passwd(self):
    with TestImage('with_passwd') as img:
      self.assertDigest(img, '41c27b4e1f3a94cff72200ae3fd2da3b0c58ae817d9fa50b398a1ec2f0cbeda1')
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
      self.assertDigest(img, 'bb9c66ef7fb8fda0c59c4ee5213ba03531015b3815a5e8bf1019a26192ee39b6')
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
      self.assertDigest(img, 'd44d966ea76f912dd24129524efa002499f01141bc98667fc791a947d1fbf084')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/group'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/group').read()
        self.assertEqual('root:x:0:\nfoobar:x:2345:foo,bar,baz\n', content)

  def test_with_empty_files(self):
    with TestImage('with_empty_files') as img:
      self.assertDigest(img, '8463cb31fa04ab4fc3f8d5ffe7c9a11f73f0d6f4da82aec36948125ed17b3ccf')
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
      self.assertDigest(img, 'af03b84219fef9d3f2810d5c4022015e6a9e6e19d836b865776636f62d101ba3')
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
