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
      self.assertDigest(img, '4fec1457d392ae22256731a2751488e493ce728519cdaf1a9fcbaba5a19b6fa7')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_files_with_file_base(self):
    with TestImage('files_with_files_base') as img:
      self.assertDigest(img, 'f964089bd474ab3897e90da5f8bb12dc6e1d24aed32113e7e4e352f6848c49e5')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_files_in_layer_with_file_base(self):
    with TestImage('files_in_layer_with_files_base') as img:
      self.assertDigest(img, '6c0d012020fb67d410d1eb48c10878d399b23611604810ba3b0c78714260cff3')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertLayerNContains(img, 2, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './baz'])
      self.assertLayerNContains(img, 0, ['.', './bar'])

  def test_tar_base(self):
    with TestImage('tar_base') as img:
      self.assertDigest(img, '5085c51e31a398a6df6c733b6ff44a3af370894dafadf3378326ea2ceb16639c')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './usr', './usr/bin', './usr/bin/unremarkabledeath'])
      # Check that this doesn't have a configured entrypoint.
      self.assertConfigEqual(img, 'Entrypoint', None)

  def test_tar_with_tar_base(self):
    with TestImage('tar_with_tar_base') as img:
      self.assertDigest(img, '63039733657557b1c8dea2dc334cd562f80fe0508ab7125f495a39bedb90ad5e')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_tars_in_layer_with_tar_base(self):
    with TestImage('tars_in_layer_with_tar_base') as img:
      self.assertDigest(img, '6a599c18b98222a914559491a54e44d728eb64ba2e0ad99c3910ce1d3ace330b')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, [
          './usr', './usr/bin', './usr/bin/unremarkabledeath'])

  def test_directory_with_tar_base(self):
    with TestImage('directory_with_tar_base') as img:
      self.assertDigest(img, '3da71fa3fc0d44814daddc198111fae0c18509a29667dc52685679069424e804')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './foo', './foo/asdf', './foo/usr',
        './foo/usr/bin', './foo/usr/bin/miraclegrow'])

  def test_files_with_tar_base(self):
    with TestImage('files_with_tar_base') as img:
      self.assertDigest(img, 'e0f3aa9744d53fda7979a70952dc7484efed02eea331795d475d367b1907c293')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './bar'])

  def test_workdir_with_tar_base(self):
    with TestImage('workdir_with_tar_base') as img:
      self.assertDigest(img, '12faa452b7db64f4f2e0bc525dce6a2801aca6f0b6d9f99e6555c34a8c2d6140')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [])
      # Check that the working directory property has been properly configured.
      self.assertConfigEqual(img, 'WorkingDir', '/tmp')

  def test_tar_with_files_base(self):
    with TestImage('tar_with_files_base') as img:
      self.assertDigest(img, 'cfa1216283bb50c248130d701000b1827ee2a3710fdb2c1021547c32697529aa')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        './asdf', './usr', './usr/bin',
        './usr/bin/miraclegrow'])

  def test_docker_tarball_base(self):
    with TestImage('docker_tarball_base') as img:
      self.assertDigest(img, '7147dfb29ecbc50f4e7fda74914ba506f0bb953aa08aff4f35dd6c48e879c614')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_layers_with_docker_tarball_base(self):
    with TestImage('layers_with_docker_tarball_base') as img:
      self.assertDigest(img, 'e191a8e4486200fda4ab0a3e8acd5063373b362602228ec40f5ba68c8f3757a3')
      self.assertEqual(5, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])
      self.assertLayerNContains(img, 1, ['.', './three', './three/three'])
      self.assertLayerNContains(img, 2, ['.', './baz'])

  def test_base_with_entrypoint(self):
    with TestImage('base_with_entrypoint') as img:
      self.assertDigest(img, '2254811e65407388ac7fc63e0e070923e08da45fe1257daeaab44cf35b371388')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'ExposedPorts', {'8080/tcp': {}})

  def test_dashdash_entrypoint(self):
    with TestImage('dashdash_entrypoint') as img:
      self.assertDigest(img, '3e297ecc20f1da36c71cf857cad46b0b3ade7acd76fc55358211c3f61b647825')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Entrypoint', ['/bar', '--'])

  def test_derivative_with_cmd(self):
    with TestImage('derivative_with_cmd') as img:
      self.assertDigest(img, 'bfcd7c33e5cedf329ae9d6c6fe92b582654d29ac0fa9bd89d0cd239982fef237')
      self.assertEqual(3, len(img.fs_layers()))

      self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
      self.assertConfigEqual(img, 'Cmd', ['arg1', 'arg2'])
      self.assertConfigEqual(
        img, 'ExposedPorts', {'8080/tcp': {}, '80/tcp': {}})

  def test_derivative_with_volume(self):
    with TestImage('derivative_with_volume') as img:
      self.assertDigest(img, '6b47b2b13686b00dc61ae13c45dd191bab86af9d22c3dbca1719ec1349aa0386')
      self.assertEqual(2, len(img.fs_layers()))

      # Check that the topmost layer has the volumes exposed by the bottom
      # layer, and itself.
      self.assertConfigEqual(img, 'Volumes', {
        '/asdf': {}, '/blah': {}, '/logs': {}
      })

  def test_with_unix_epoch_creation_time(self):
    with TestImage('with_unix_epoch_creation_time') as img:
      self.assertDigest(img, 'e96a2c4e8708036e27ca664b860fe55afcc2201d970f55396686c59da127332b')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('2009-02-13T23:31:30.119999885Z', cfg.get('created', ''))

  def test_with_millisecond_unix_epoch_creation_time(self):
    with TestImage('with_millisecond_unix_epoch_creation_time') as img:
      self.assertDigest(img, '92c0693ea78743e87184e1f59190b19f65d3dfec871c47958f6f6e182ace4924')
      self.assertEqual(2, len(img.fs_layers()))
      cfg = json.loads(img.config_file())
      self.assertEqual('2009-02-13T23:31:30.12345004Z', cfg.get('created', ''))

  def test_with_rfc_3339_creation_time(self):
    with TestImage('with_rfc_3339_creation_time') as img:
      self.assertDigest(img, '00b41239d8927b23c61b5e071d622ff08fc6e3494be030cb80ed6cdef639feee')
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
      self.assertDigest(img, 'dee53e65c09c5de80b1683e5853bb0978785e4cdd17e9ba2e731e3c7fe13b62b')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', ['bar=blah blah blah', 'foo=/asdf'])

  def test_layers_with_env(self):
    with TestImage('layers_with_env') as img:
      self.assertDigest(img, '4eac1194bc795eeca8af317b4e39ea39d77e3c63af285e011c6e4ca3d163eae2')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [u'PATH=$PATH:/tmp/a:/tmp/b:/tmp/c', u'a=b', u'x=y'])

  def test_dummy_repository(self):
    # We allow users to specify an alternate repository name instead of 'bazel/'
    # to prefix their image names.
    name = 'gcr.io/dummy/%s:dummy_repository' % TEST_DATA_TARGET_BASE
    with TestBundleImage('dummy_repository', name) as img:
      self.assertDigest(img, '263c21a78525a72767e07918115c78778e1880bd287c588135f3e73c22eb6fec')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './foo'])

  def test_with_double_env(self):
    with TestImage('with_double_env') as img:
      self.assertDigest(img, '909c654164cc0aee13d90bf45b8ea018c83c31d63e2f2281ec44293fcc37a3f1')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Env', [
        'bar=blah blah blah',
        'baz=/asdf blah blah blah',
        'foo=/asdf'])

  def test_with_label(self):
    with TestImage('with_label') as img:
      self.assertDigest(img, 'b0b8cd5f747bb300639fc1da1c3cf91efc35e21b3beb7719d94a415689e5b16a')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        'com.example.bar': '{"name": "blah"}',
        'com.example.baz': 'qux',
        'com.example.foo': '{"name": "blah"}',
      })

  def test_with_double_label(self):
    with TestImage('with_double_label') as img:
      self.assertDigest(img, 'e76e73489265fc49f14f00488a468f7757da03a6b7ab150281bb028df873d824')
      self.assertEqual(3, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {
        'com.example.bar': '{"name": "blah"}',
        'com.example.baz': 'qux',
        'com.example.foo': '{"name": "blah"}',
        'com.example.qux': '{"name": "blah-blah"}',
      })

  def test_with_user(self):
    with TestImage('with_user') as img:
      self.assertDigest(img, 'c26736d5b9bb34f7b909505891c4c8c57ab7c2fea672ede181a34d56c4f72382')
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'User', 'nobody')

  def test_data_path(self):
    # Without data_path = "." the file will be inserted as `./test`
    # (since it is the path in the package) and with data_path = "."
    # the file will be inserted relatively to the testdata package
    # (so `./test/test`).
    with TestImage('no_data_path_image') as img:
      self.assertDigest(img, 'b503bec6abb42484126bbe48e6e4d812d3226d3cdcc4ab9f058cf7eda2678a5d')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test'])
    with TestImage('data_path_image') as img:
      self.assertDigest(img, '7f1e0cfcdf487fe110b8c3856937e76266b4117bf1818b9bffda53cbeccf5db6')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './test', './test/test'])

    # With an absolute path for data_path, we should strip that prefix
    # from the files' paths. Since the testdata images are in
    # //testdata and data_path is set to
    # "/tools/build_defs", we should have `docker` as the top-level
    # directory.
    with TestImage('absolute_data_path_image') as img:
      self.assertDigest(img, 'd9a9dc07993b14f3e1831468681452dae408e7ef64c0da3c1c062737a7af7be9')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, [
        '.', './testdata', './testdata/test', './testdata/test/test'])
      # With data_path = "/", we expect the entire path from the repository
      # root.
    with TestImage('root_data_path_image') as img:
      self.assertDigest(img, 'd9a9dc07993b14f3e1831468681452dae408e7ef64c0da3c1c062737a7af7be9')
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
        self.assertDigest(img, 'c26736d5b9bb34f7b909505891c4c8c57ab7c2fea672ede181a34d56c4f72382')
    with TestBundleImage('bundle_test', 'index.docker.io/library/ubuntu:latest') as img:
      self.assertDigest(img, '2254811e65407388ac7fc63e0e070923e08da45fe1257daeaab44cf35b371388')
      self.assertEqual(1, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'us.gcr.io/google-appengine/base:fresh') as img:
      self.assertDigest(img, 'f36023b46dd68219d987e3ea08c8d33348030c53181563d5f167ddc658591790')
      self.assertEqual(2, len(img.fs_layers()))
    with TestBundleImage(
        'bundle_test', 'gcr.io/google-containers/pause:2.0') as img:
      self.assertDigest(img, '909c654164cc0aee13d90bf45b8ea018c83c31d63e2f2281ec44293fcc37a3f1')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_stamped_label(self):
    with TestImage('with_stamp_label') as img:
      self.assertEqual(2, len(img.fs_layers()))
      self.assertConfigEqual(img, 'Labels', {'BUILDER': STAMP_DICT['BUILD_USER']})

  def test_pause_based(self):
    with TestImage('pause_based') as img:
      self.assertDigest(img, '237c4891b3967fb542902f1ef68a7e22fb172fc79b4968fa946e2c966af4f8da')
      self.assertEqual(3, len(img.fs_layers()))

  def test_pause_piecemeal(self):
    with TestImage('pause_piecemeal/image') as img:
      self.assertDigest(img, 'e0dc994f5572c640b3518f95627310b3c50b23caccd75a6ba54fa14c54b65a78')
      self.assertEqual(2, len(img.fs_layers()))

  def test_pause_piecemeal_gz(self):
    with TestImage('pause_piecemeal_gz/image') as img:
      self.assertDigest(img, 'e0dc994f5572c640b3518f95627310b3c50b23caccd75a6ba54fa14c54b65a78')

  def test_build_with_tag(self):
    with TestBundleImage('build_with_tag', 'gcr.io/build/with:tag') as img:
      self.assertDigest(img, 'c759e4c48d4cc96cdadd94ff3531236ae46ccaf52d405da34eb48c0008c15f8c')
      self.assertEqual(3, len(img.fs_layers()))

  def test_with_passwd(self):
    with TestImage('with_passwd') as img:
      self.assertDigest(img, 'bd6437cae7fcf0e4808a07eb152882016a9270be8bb3f10a1eca10b79871f614')
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
      self.assertDigest(img, '66d16db1c8f48c5248b7e9d07cd8b1079112914db1a810db1cfaf6b99d91a90a')
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
      self.assertDigest(img, 'ca3c702c26b4f6ba8fe6ed66dcf3f636ea8b6722c549f59af3d24cc383fda854')
      self.assertEqual(1, len(img.fs_layers()))
      self.assertTopLayerContains(img, ['.', './etc', './etc/group'])

      buf = cStringIO.StringIO(img.blob(img.fs_layers()[0]))
      with tarfile.open(fileobj=buf, mode='r') as layer:
        content = layer.extractfile('./etc/group').read()
        self.assertEqual('root:x:0:\nfoobar:x:2345:foo,bar,baz\n', content)

  def test_with_empty_files(self):
    with TestImage('with_empty_files') as img:
      self.assertDigest(img, '106f67a7f34217493cba0096b52298169447a5e84508e9fcc8047be6cbc17ef5')
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
      self.assertDigest(img, '0f1783465bf13737f21c3230155da73a461ca445b2d4f7679d0e5bd868f4fed2')
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
