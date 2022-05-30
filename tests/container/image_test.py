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

from io import BytesIO
import datetime
import json
import os
import tarfile
import unittest

from containerregistry.client import docker_name
from containerregistry.client.v2_2 import docker_image as v2_2_image

TEST_DATA_TARGET_BASE = 'testdata'
DIR_PERMISSION = 0o700
PASSWD_FILE_MODE = 0o644
# Dictionary of key to value mappings in the Bazel stamp file
STAMP_DICT = {}


def TestRunfilePath(*args):
    """Convert a path to a file target to the runfile path"""
    return os.path.join(os.environ['TEST_SRCDIR'], 'io_bazel_rules_docker', *args)


def TestData(name):
    return TestRunfilePath(TEST_DATA_TARGET_BASE, name)


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
        buf = BytesIO(img.blob(img.fs_layers()[n]))
        with tarfile.open(fileobj=buf, mode='r') as layer:
            self.assertTarballContains(layer, paths)

    def assertNonZeroMtimesInTopLayer(self, img):
        buf = BytesIO(img.blob(img.fs_layers()[0]))
        with tarfile.open(fileobj=buf, mode='r') as layer:
            for member in layer.getmembers():
                self.assertNotEqual(member.mtime, 0)

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
            self.assertDigest(
                img, '84a3ebbfae2f49509b76c0beb3414b10fdd1bb0ceeed457754a3e44a251ed019')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './foo'])

    def test_files_with_file_base(self):
        with TestImage('files_with_files_base') as img:
            self.assertDigest(
                img, '6793f8771bd38ebed45f5a4516fb67ada632d06b2fc0179e95e01847448c8386')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './bar'])

    def test_files_in_layer_with_file_base(self):
        with TestImage('files_in_layer_with_files_base') as img:
            self.assertDigest(
                img, '828eb1d0daa2f797497ec54de421e79a663429e0e791b246c420e84ec171fe7f')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertLayerNContains(img, 2, ['.', './foo'])
            self.assertLayerNContains(img, 1, ['.', './baz'])
            self.assertLayerNContains(img, 0, ['.', './bar'])

    def test_tar_base(self):
        with TestImage('tar_base') as img:
            self.assertDigest(
                img, '1f952b078e8d380fce4097857f32823976203ed4aaa54821773474f98012bfac')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                './usr', './usr/bin', './usr/bin/unremarkabledeath'])
            # Check that this doesn't have a configured entrypoint.
            self.assertConfigEqual(img, 'Entrypoint', None)

    def test_tar_with_mtimes_preserved(self):
        with TestImage('tar_with_mtimes_preserved') as img:
            self.assertDigest(
                img, '8167d35b2267136fbb68f92b68fef2893000d74f372d4b694d6b53ca79a20146')
            self.assertNonZeroMtimesInTopLayer(img)

    def test_tar_with_tar_base(self):
        with TestImage('tar_with_tar_base') as img:
            self.assertDigest(
                img, '3bb6c0ebe52f6f4a76562eee9d79c4c46ff9d9dad749ef55f949d089f7a36b0a')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                './asdf', './usr', './usr/bin',
                './usr/bin/miraclegrow'])

    def test_tars_in_layer_with_tar_base(self):
        with TestImage('tars_in_layer_with_tar_base') as img:
            self.assertDigest(
                img, 'accf4062e218d20cdcc661dcd5d4ff4f4818d5bc8641db1ed00c884d46ec6999')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                './asdf', './usr', './usr/bin',
                './usr/bin/miraclegrow'])
            self.assertLayerNContains(
                img, 1, ['.', './three', './three/three'])
            self.assertLayerNContains(img, 2, [
                './usr', './usr/bin', './usr/bin/unremarkabledeath'])

    def test_directory_with_tar_base(self):
        with TestImage('directory_with_tar_base') as img:
            self.assertDigest(
                img, '8fccb0a6c600b88fe117c81e368d62ad558b945cff8927110afed9f4072d2483')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                '.', './foo', './foo/asdf', './foo/usr',
                './foo/usr/bin', './foo/usr/bin/miraclegrow'])

    def test_files_with_tar_base(self):
        with TestImage('files_with_tar_base') as img:
            self.assertDigest(
                img, '3ce522f4f9f80249eb75b9b7083a24b17f45c607a40f3d54418c6bad355b399f')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './bar'])

    def test_workdir_with_tar_base(self):
        with TestImage('workdir_with_tar_base') as img:
            self.assertDigest(
                img, '242ac990f663c8c49e540d470112b21dbf001b1c984097ab787f4af900543c47')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, [])
            # Check that the working directory property has been properly configured.
            self.assertConfigEqual(img, 'WorkingDir', '/tmp')

    def test_tar_with_files_base(self):
        with TestImage('tar_with_files_base') as img:
            self.assertDigest(
                img, 'c1d46001de2e021dcc6943351cc62d1f236c6a3528132ca9014c28dc5bb19d02')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                './asdf', './usr', './usr/bin',
                './usr/bin/miraclegrow'])

    def test_docker_tarball_base(self):
        with TestImage('docker_tarball_base') as img:
            self.assertDigest(
                img, '67c9957f23377c8902412429c02c006a8a55fffaa6f44a9963a08aa1986abf01')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './foo'])

    def test_layers_with_docker_tarball_base(self):
        with TestImage('layers_with_docker_tarball_base') as img:
            self.assertDigest(
                img, 'c0d4751af7d72f7ce80e3997dadfad4f176823743e1b0a5af147d55f70a0c8d5')
            self.assertEqual(5, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './foo'])
            self.assertLayerNContains(
                img, 1, ['.', './three', './three/three'])
            self.assertLayerNContains(img, 2, ['.', './baz'])

    def test_base_with_entrypoint(self):
        with TestImage('base_with_entrypoint') as img:
            self.assertDigest(
                img, 'b8460d575a3d4558057bbdb6f05988259b4f61b1b1f3f117b941043e486914a2')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
            self.assertConfigEqual(img, 'ExposedPorts', {'8080/tcp': {}})

    def test_dashdash_entrypoint(self):
        with TestImage('dashdash_entrypoint') as img:
            self.assertDigest(
                img, '921b63580668951c8d1444cd419eecaf64b4a86c86de9a8f657f863201d15962')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertConfigEqual(img, 'Entrypoint', ['/bar', '--'])

    def test_derivative_with_cmd(self):
        with TestImage('derivative_with_cmd') as img:
            self.assertDigest(
                img, 'a861490554b3658254af83568adfc83992dc796dbc425fb6f0db35cef2e216ee')
            self.assertEqual(3, len(img.fs_layers()))

            self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
            self.assertConfigEqual(img, 'Cmd', ['arg1', 'arg2'])
            self.assertConfigEqual(
                img, 'ExposedPorts', {'8080/tcp': {}, '80/tcp': {}})

    def test_derivative_with_volume(self):
        with TestImage('derivative_with_volume') as img:
            self.assertDigest(
                img, 'f6c5b0e90cd0f22581669e0b4efd2b530c746bf50b9a8945c584456eafc0ffb6')
            self.assertEqual(2, len(img.fs_layers()))

            # Check that the topmost layer has the volumes exposed by the bottom
            # layer, and itself.
            self.assertConfigEqual(img, 'Volumes', {
                '/asdf': {}, '/blah': {}, '/logs': {}
            })

    def test_with_unix_epoch_creation_time(self):
        with TestImage('with_unix_epoch_creation_time') as img:
            self.assertDigest(
                img, 'bc6b0d9457585177d993fa23492f044e6ca3801096d34fef6bb2051f98f65b56')
            self.assertEqual(2, len(img.fs_layers()))
            cfg = json.loads(img.config_file())
            self.assertEqual('2009-02-13T23:31:30.119999885Z',
                             cfg.get('created', ''))

    def test_with_millisecond_unix_epoch_creation_time(self):
        with TestImage('with_millisecond_unix_epoch_creation_time') as img:
            self.assertDigest(
                img, '6fbbd791c5daba03ff50f181cabe5a1cd1088979598f9cdc356ecf7653d39170')
            self.assertEqual(2, len(img.fs_layers()))
            cfg = json.loads(img.config_file())
            self.assertEqual('2009-02-13T23:31:30.12345004Z',
                             cfg.get('created', ''))

    def test_with_rfc_3339_creation_time(self):
        with TestImage('with_rfc_3339_creation_time') as img:
            self.assertDigest(
                img, '58a8333ae43fe3e22d91ad8cbf0e171f3b97724e2421bdd16a9b2dcdd343f7e3')
            self.assertEqual(2, len(img.fs_layers()))
            cfg = json.loads(img.config_file())
            self.assertEqual('1989-05-03T12:58:12.345Z',
                             cfg.get('created', ''))

    # This test is flaky. If it fails, do a bazel clean --expunge_async and try again
    def test_with_stamped_creation_time(self):
        with TestImage('with_stamped_creation_time') as img:
            self.assertEqual(2, len(img.fs_layers()))
            cfg = json.loads(img.config_file())
            created_str = cfg.get('created', '')
            self.assertNotEqual('', created_str)

            now = datetime.datetime.utcnow()

            created = datetime.datetime.strptime(
                created_str, '%Y-%m-%dT%H:%M:%SZ')

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

            created = datetime.datetime.strptime(
                created_str, '%Y-%m-%dT%H:%M:%SZ')

            # The BUILD_TIMESTAMP is set by Bazel to Java's CurrentTimeMillis / 1000,
            # or env['SOURCE_DATE_EPOCH']. For Bazel versions before 0.12, there was
            # a bug where CurrentTimeMillis was not divided by 1000.
            # See https://github.com/bazelbuild/bazel/issues/2240
            # https://bazel-review.googlesource.com/c/bazel/+/48211
            # Assume that any value for 'created' within a reasonable bound is fine.
            self.assertLessEqual(now - created, datetime.timedelta(minutes=15))

    def test_with_base_stamped_image(self):
        # {BUILD_TIMESTAMP} should be the default when `stamp = True` is configured
        # in the base image and `creation_time` isn't explicitly defined.
        with TestImage('with_base_stamped_image') as img:
            self.assertEqual(3, len(img.fs_layers()))
            cfg = json.loads(img.config_file())
            created_str = cfg.get('created', '')
            self.assertNotEqual('', created_str)

            now = datetime.datetime.utcnow()

            created = datetime.datetime.strptime(
                created_str, '%Y-%m-%dT%H:%M:%SZ')

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
            self.assertDigest(
                img, '584c94c1660cd04e74f0aca32f2cb8d8696ee7826cce93b0cd21d6c870825238')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertConfigEqual(
                img, 'Env', ['bar=blah blah blah', 'foo=/asdf'])

    def test_layers_with_env(self):
        with TestImage('layers_with_env') as img:
            self.assertDigest(
                img, '200f73a0fcbe4f58beb411bd3f649ed1fc847e14353f1ec832ed377c17ffd2fb')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertConfigEqual(
                img, 'Env', [u'PATH=$PATH:/tmp/a:/tmp/b:/tmp/c', u'a=b', u'x=y'])

    def test_dummy_repository(self):
        # We allow users to specify an alternate repository name instead of 'bazel/'
        # to prefix their image names.
        name = 'gcr.io/dummy/%s:dummy_repository' % TEST_DATA_TARGET_BASE
        with TestBundleImage('dummy_repository', name) as img:
            self.assertDigest(
                img, '501c30ee6cb53cedc90d6b050e65bb44fd3fc81d25f0e868f95fedd31f32b097')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './foo'])

    def test_with_double_env(self):
        with TestImage('with_double_env') as img:
            self.assertDigest(
                img, '0643112fd89f93bac6f39cd43f789aadfafae888199010af134f80de581d62ef')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertConfigEqual(img, 'Env', [
                'bar=blah blah blah',
                'baz=/asdf blah blah blah',
                'foo=/asdf'])

    def test_with_label(self):
        with TestImage('with_label') as img:
            self.assertDigest(
                img, '89b3df22e6375b6a46bf7cd64729a9c593e9604492eacaf089fc3ef9ae4f5804')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertConfigEqual(img, 'Labels', {
                'com.example.bar': '{"name": "blah"}',
                'com.example.baz': 'qux',
                'com.example.foo': '{"name": "blah"}',
            })

    def test_with_double_label(self):
        with TestImage('with_double_label') as img:
            self.assertDigest(
                img, '03020ef43356189c27c77fd1dfec3153f7b8bfd15b449eef171f0d5f93ffd156')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertConfigEqual(img, 'Labels', {
                'com.example.bar': '{"name": "blah"}',
                'com.example.baz': 'qux',
                'com.example.foo': '{"name": "blah"}',
                'com.example.qux': '{"name": "blah-blah"}',
            })

    def test_with_user(self):
        with TestImage('with_user') as img:
            self.assertDigest(
                img, '4e1eef44f9c6deb8e83494a8a815d7f88ed0a411499e8e166942ac3f8930ec8a')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertConfigEqual(img, 'User', 'nobody')

    def test_data_path(self):
        # Without data_path = "." the file will be inserted as `./test`
        # (since it is the path in the package) and with data_path = "."
        # the file will be inserted relatively to the testdata package
        # (so `./test/test`).
        with TestImage('no_data_path_image') as img:
            self.assertDigest(
                img, 'd6ea07a7074a7c9cb29c98a064dd900e6f90e7be0628d71c8da509dee419220c')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './test'])
        with TestImage('data_path_image') as img:
            self.assertDigest(
                img, 'c1eca42703357ed58c72bc726450d55ec5d1f1220089a9e447c3ad5b5f1e8356')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './test', './test/test'])

        # With an absolute path for data_path, we should strip that prefix
        # from the files' paths. Since the testdata images are in
        # //testdata and data_path is set to
        # "/tools/build_defs", we should have `docker` as the top-level
        # directory.
        with TestImage('absolute_data_path_image') as img:
            self.assertDigest(
                img, 'f2aff195a73deb3eff246f1b97a46ef8b634ca89e2b88a43cc000db745460bef')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                '.', './testdata', './testdata/test', './testdata/test/test'])
            # With data_path = "/", we expect the entire path from the repository
            # root.
        with TestImage('root_data_path_image') as img:
            self.assertDigest(
                img, 'f2aff195a73deb3eff246f1b97a46ef8b634ca89e2b88a43cc000db745460bef')
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
                '.', './baz', './bar', ])

    def test_bundle(self):
        with TestBundleImage('stamped_bundle_test', "example.com/aaaaa{BUILD_USER}:stamped".format(
            BUILD_USER=STAMP_DICT['BUILD_USER']
        )) as img:
            self.assertDigest(
                img, '4e1eef44f9c6deb8e83494a8a815d7f88ed0a411499e8e166942ac3f8930ec8a')
        with TestBundleImage('bundle_test', 'docker.io/ubuntu:latest') as img:
            self.assertDigest(
                img, 'b8460d575a3d4558057bbdb6f05988259b4f61b1b1f3f117b941043e486914a2')
            self.assertEqual(1, len(img.fs_layers()))
        with TestBundleImage(
                'bundle_test', 'us.gcr.io/google-appengine/base:fresh') as img:
            self.assertDigest(
                img, '9117535b880556343e328aa20a08a8a2161173371c0e587ce4c7d3a9a4d1d12e')
            self.assertEqual(2, len(img.fs_layers()))
        with TestBundleImage(
                'bundle_test', 'gcr.io/google-containers/pause:2.0') as img:
            self.assertDigest(
                img, '0643112fd89f93bac6f39cd43f789aadfafae888199010af134f80de581d62ef')
            self.assertEqual(3, len(img.fs_layers()))

    def test_with_stamped_label(self):
        with TestImage('with_stamp_label') as img:
            self.assertEqual(2, len(img.fs_layers()))
            self.assertConfigEqual(
                img, 'Labels', {'BUILDER': STAMP_DICT['BUILD_USER']})

    def test_pause_based(self):
        with TestImage('pause_based') as img:
            self.assertDigest(
                img, '29ce23be35b02e583cd4b5836024b6cb4e942a8e5e09671de97ae33ed4f06fb9')
            self.assertEqual(3, len(img.fs_layers()))

    def test_pause_piecemeal(self):
        with TestImage('pause_piecemeal/image') as img:
            self.assertDigest(
                img, 'ca362da80137d6e22de45cac9705271c694e63d87d4f98f1485288e83bda7334')
            self.assertEqual(2, len(img.fs_layers()))

    def test_pause_piecemeal_gz(self):
        with TestImage('pause_piecemeal_gz/image') as img:
            self.assertDigest(
                img, 'ca362da80137d6e22de45cac9705271c694e63d87d4f98f1485288e83bda7334')

    def test_build_with_tag(self):
        with TestBundleImage('build_with_tag', 'gcr.io/build/with:tag') as img:
            self.assertDigest(
                img, '388ccb8b26078eb6dc12e4204e93835fe1886033b1848a964abb71d3c4acb890')
            self.assertEqual(3, len(img.fs_layers()))

    def test_with_passwd(self):
        with TestImage('with_passwd') as img:
            self.assertDigest(
                img, '81420a14782ff8a0de928199d7e3e5bbf8684f02a977326b96d863329c97f055')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './etc', './etc/passwd'])

            buf = BytesIO(img.blob(img.fs_layers()[0]))
            with tarfile.open(fileobj=buf, mode='r') as layer:
                content = layer.extractfile('./etc/passwd').read()
                self.assertEqual(
                    b'root:x:0:0:Root:/root:/rootshell\nfoobar:x:1234:2345:myusernameinfo:/myhomedir:/myshell\nnobody:x:65534:65534:nobody with no home:/nonexistent:/sbin/nologin\n',
                    content)
                self.assertEqual(layer.getmember(
                    "./etc/passwd").mode, PASSWD_FILE_MODE)

    def test_with_passwd_tar(self):
        with TestImage('with_passwd_tar') as img:
            self.assertDigest(
                img, 'a87a5060f2abb7dccbd61bf303f66561a170da43076afeeb4dee4444f8e4b5d3')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(
                img, ['.', './etc', './etc/password', './root', './myhomedir'])

            buf = BytesIO(img.blob(img.fs_layers()[0]))
            with tarfile.open(fileobj=buf, mode='r') as layer:
                content = layer.extractfile('./etc/password').read()
                self.assertEqual(
                    b'root:x:0:0:Root:/root:/rootshell\nfoobar:x:1234:2345:myusernameinfo:/myhomedir:/myshell\nnobody:x:65534:65534:nobody with no home:/nonexistent:/sbin/nologin\n',
                    content)
                self.assertEqual(layer.getmember(
                    "./etc/password").mode, PASSWD_FILE_MODE)
                self.assertTarInfo(layer.getmember("./root"),
                                   0, 0, DIR_PERMISSION, True)
                self.assertTarInfo(layer.getmember(
                    "./myhomedir"), 1234, 2345, DIR_PERMISSION, True)

    def test_with_group(self):
        with TestImage('with_group') as img:
            self.assertDigest(
                img, '3abaf45eda502f6826f3745627c707cd0ac12536915fa8ed45883fe21aaac075')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './etc', './etc/group'])

            buf = BytesIO(img.blob(img.fs_layers()[0]))
            with tarfile.open(fileobj=buf, mode='r') as layer:
                content = layer.extractfile('./etc/group').read()
                self.assertEqual(
                    b'root:x:0:\nfoobar:x:2345:foo,bar,baz\n', content)

    def test_with_empty_files(self):
        with TestImage('with_empty_files') as img:
            self.assertDigest(
                img, '8f69b3fadd1b35804d526880f3ed4d9687dea623d5510ba67a0917cdc73e145c')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './file1', './file2'])

            buf = BytesIO(img.blob(img.fs_layers()[0]))
            with tarfile.open(fileobj=buf, mode='r') as layer:
                for name in ('./file1', './file2'):
                    memberfile = layer.getmember(name)
                    self.assertEqual(0, memberfile.size)
                    self.assertEqual(0o777, memberfile.mode)

    def test_with_empty_dirs(self):
        with TestImage('with_empty_dirs') as img:
            self.assertDigest(
                img, '6ac23017e088e15e05df6533787c053e766c1ff6705eab5110226127115a8a21')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './etc', './foo', './bar'])

            buf = BytesIO(img.blob(img.fs_layers()[0]))
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
        imgPath = TestRunfilePath(
            "tests", "container", "basic_windows_image.tar")
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
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps',
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six',
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/__init__.py',
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/test',
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/test/__init__.py',
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/__init__.py',
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict',
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/__init__.py',
                './app/testdata/py_image_complex.binary.runfiles/__init__.py',
                './app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/testdata/__init__.py',
                './app/io_bazel_rules_docker',
                '/app',
                '/app/testdata',
                '/app/testdata/py_image_complex.binary',
                '/app/testdata/py_image_complex.binary.runfiles',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker/external'
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
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/__init__.py',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six.py',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/DESCRIPTION.rst',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/METADATA',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/RECORD',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/WHEEL',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/metadata.json',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/top_level.txt',
            ])

            # bazel-bin/testdata/py_image_complex.1-layer.tar
            self.assertLayerNContains(img, 6, [
                '.',
                './app',
                './app/io_bazel_rules_docker_pip_deps',
                './app/io_bazel_rules_docker_pip_deps/pypi__six',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/__init__.py',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six.py',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/DESCRIPTION.rst',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/METADATA',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/RECORD',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/WHEEL',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/metadata.json',
                './app/io_bazel_rules_docker_pip_deps/pypi__six/six-1.11.0.dist-info/top_level.txt',
            ])

            # bazel-bin/testdata/py_image_complex.0-symlinks-layer.tar
            self.assertLayerNContains(img, 7, [
                '.',
                '/app',
                '/app/testdata',
                '/app/testdata/py_image_complex.binary.runfiles',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/__init__.py',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict/__init__.py',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict/addict.py',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/METADATA',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/RECORD',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/WHEEL',
                '/app/testdata/py_image_complex.binary.runfiles/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/top_level.txt',
            ])

            # bazel-bin/testdata/py_image_complex.0-layer.tar
            self.assertLayerNContains(img, 8, [
                '.',
                './app',
                './app/io_bazel_rules_docker_pip_deps',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/__init__.py',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict/__init__.py',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict/addict.py',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/METADATA',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/RECORD',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/WHEEL',
                './app/io_bazel_rules_docker_pip_deps/pypi__addict/addict-2.1.2.dist-info/top_level.txt',
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

    def test_nodejs_image(self):
        self.maxDiff = None
        with TestImage('nodejs_image') as img:
            # TODO: remove all '/app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/external'
            # once --noexternal_legacy_runfiles is enabled
            # https://github.com/bazelbuild/rules_docker/issues/1350

            # Check the application layer (top layer), which also contains symlinks to the bottom layers.
            self.assertTopLayerContains(img, [
                '.',
                './app',
                './app/testdata',
                './app/testdata/nodejs_image_binary.runfiles',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/testdata',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/testdata/nodejs_image.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/linker',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/linker/index.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/runfiles',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/runfiles/index.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/runfiles/runfile_helper_main.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/node',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/node/node_patches.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/coverage',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/coverage/lcov_merger-js.js',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/testdata/_nodejs_image_binary.module_mappings.json',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/bazelbuild',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/bazelbuild/bazel',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/bazelbuild/bazel/tools',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/bazelbuild/bazel/tools/bash',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/bazelbuild/bazel/tools/bash/runfiles',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/bazelbuild/bazel/tools/bash/runfiles/runfiles.bash',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/testdata/nodejs_image_binary_loader.js',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/testdata/nodejs_image_binary_require_patch.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/buffer-from',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/buffer-from/package.json',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/buffer-from/index.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/package.json',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/source-map.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/array-set.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/base64-vlq.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/base64.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/binary-search.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/mapping-list.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/quick-sort.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/source-map-consumer.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/source-map-generator.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/source-node.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map/lib/util.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map-support',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map-support/package.json',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map-support/register.js',
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/third_party/github.com/source-map-support/source-map-support.js',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/testdata/nodejs_image_lib.js',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/testdata/nodejs_image_lib.d.ts',
                './app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/testdata/nodejs_image_binary.sh',
                '/app',
                '/app/testdata',
                '/app/testdata/nodejs_image_binary',
                '/app/testdata/nodejs_image_binary.runfiles',
                '/app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker',
                '/app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/external'])

            # Check that the next layer contains node_modules
            layerOneFiles = ['.',
                             './app',
                             './app/testdata',
                             './app/testdata/nodejs_image_binary.runfiles',
                             './app/testdata/nodejs_image_binary.runfiles/npm',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/jsesc',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/jsesc/LICENSE',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/jsesc/README.md',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/jsesc/index.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/jsesc/package.json',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/LICENSE',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/README.md',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/assert.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/async_hooks.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/base.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/buffer.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/child_process.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/cluster.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/console.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/constants.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/crypto.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/dgram.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/dns.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/domain.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/events.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/fs.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/globals.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/globals.global.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/http.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/http2.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/https.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/index.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/inspector.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/module.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/net.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/os.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/package.json',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/path.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/perf_hooks.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/process.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/punycode.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/querystring.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/readline.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/repl.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/stream.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/string_decoder.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/timers.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/tls.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/trace_events.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.2',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.2/base.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.2/fs.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.2/globals.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.2/index.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.2/util.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.4',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.4/base.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.4/globals.global.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.4/index.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.7',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.7/assert.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.7/base.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/ts3.7/index.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/tty.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/url.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/util.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/v8.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/vm.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/worker_threads.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/@types/node/zlib.d.ts',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc/LICENSE-MIT.txt',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc/README.md',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc/bin',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc/bin/jsesc',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc/jsesc.js',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc/man',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc/man/jsesc.1',
                             './app/testdata/nodejs_image_binary.runfiles/npm/node_modules/jsesc/package.json',
                             '/app',
                             '/app/testdata',
                             '/app/testdata/nodejs_image_binary',
                             '/app/testdata/nodejs_image_binary.runfiles',
                             '/app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker',
                             '/app/testdata/nodejs_image_binary.runfiles/io_bazel_rules_docker/external']
            self.assertLayerNContains(img, 1, layerOneFiles)

            # Check that the next layer contains node_args
            layerTwoFiles = [
                '.',
                './app',
                './app/testdata',
                './app/testdata/nodejs_image_binary.runfiles',
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64'.format(
                    os.sys.platform),
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64/bin'.format(
                    os.sys.platform),
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64/bin/node_repo_args.sh'.format(
                    os.sys.platform),
            ]
            self.assertLayerNContains(img, 2, layerTwoFiles)

            # Check that the next layer contains node runfiles
            layerThreeFiles = [
                '.',
                './app',
                './app/testdata',
                './app/testdata/nodejs_image_binary.runfiles',
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64'.format(
                    os.sys.platform),
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64/bin'.format(
                    os.sys.platform),
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64/bin/nodejs'.format(
                    os.sys.platform),
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64/bin/nodejs/bin'.format(
                    os.sys.platform),
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64/bin/nodejs/bin/node'.format(
                    os.sys.platform),
            ]
            self.assertLayerNContains(img, 3, layerThreeFiles)

            # Check that the next layer contains node
            layerFourFiles = [
                '.',
                './app',
                './app/testdata',
                './app/testdata/nodejs_image_binary.runfiles',
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64'.format(
                    os.sys.platform),
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64/bin'.format(
                    os.sys.platform),
                './app/testdata/nodejs_image_binary.runfiles/nodejs_{}_amd64/bin/node'.format(
                    os.sys.platform)
            ]
            self.assertLayerNContains(img, 4, layerFourFiles)

    # Re-enable once https://github.com/bazelbuild/rules_d/issues/14 is fixed.
    # def test_d_image_args(self):
    #  with TestImage('d_image') as img:
    #    self.assertConfigEqual(img, 'Entrypoint', [
    #      '/app/testdata/d_image_binary',
    #      'arg0',
    #      'arg1'])

    def test_compression_gzip(self):
        fast_bytes = os.stat(
            TestData('compression_gzip_fast-layer.tar.gz')).st_size
        normal_bytes = os.stat(
            TestData('compression_gzip_normal-layer.tar.gz')).st_size
        self.assertLess(normal_bytes, fast_bytes,
                        'layer with normal compression (%dB) not smaller than layer with fast compression (%dB)' % (
                            normal_bytes, fast_bytes))


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
