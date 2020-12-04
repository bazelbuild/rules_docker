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
                img, '83eeb10d7699ce30c6fcc7246540da38ef91802d2c0ce1c378b6b66d335f25fe')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './foo'])

    def test_files_with_file_base(self):
        with TestImage('files_with_files_base') as img:
            self.assertDigest(
                img, '2dcc8b4e1e0dac1b2b3845e239dd67528e8fe92fe5954264a383381d1345bfab')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './bar'])

    def test_files_in_layer_with_file_base(self):
        with TestImage('files_in_layer_with_files_base') as img:
            self.assertDigest(
                img, '6f685967678e9eb6a5c8aed9a47c519e90c0fd253e433831d610885eb364d287')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertLayerNContains(img, 2, ['.', './foo'])
            self.assertLayerNContains(img, 1, ['.', './baz'])
            self.assertLayerNContains(img, 0, ['.', './bar'])

    def test_tar_base(self):
        with TestImage('tar_base') as img:
            self.assertDigest(
                img, '4ae5617fb03c1528b7871623ebe37c8baa51bfd9dfdc099161d3c1de12807cc5')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                './usr', './usr/bin', './usr/bin/unremarkabledeath'])
            # Check that this doesn't have a configured entrypoint.
            self.assertConfigEqual(img, 'Entrypoint', None)

    def test_tar_with_mtimes_preserved(self):
        with TestImage('tar_with_mtimes_preserved') as img:
            self.assertDigest(
                img, 'bb41dd8b5c85c51fb4e88ddcb293a1b484ebf0615a8eacf7a617583b711616c8')
            self.assertNonZeroMtimesInTopLayer(img)

    def test_tar_with_tar_base(self):
        with TestImage('tar_with_tar_base') as img:
            self.assertDigest(
                img, '0cbaf0a5f3dfeb37dc4d30eebedfe667988bc95edbfee88357a99ecbdbeb3df8')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                './asdf', './usr', './usr/bin',
                './usr/bin/miraclegrow'])

    def test_tars_in_layer_with_tar_base(self):
        with TestImage('tars_in_layer_with_tar_base') as img:
            self.assertDigest(
                img, '6e95a8d96bded6f360a46c0a7dd0abe28280c2ef96ac5dd48b780182489a0907')
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
                img, '20428e13bc65d571c97381b27badb0c100c9800d46d3633e04711c9624329de3')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                '.', './foo', './foo/asdf', './foo/usr',
                './foo/usr/bin', './foo/usr/bin/miraclegrow'])

    def test_files_with_tar_base(self):
        with TestImage('files_with_tar_base') as img:
            self.assertDigest(
                img, 'dbff2c6807875670dbe6c1552980ab219f1faa07e973f242af1e54ff2abb5205')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './bar'])

    def test_workdir_with_tar_base(self):
        with TestImage('workdir_with_tar_base') as img:
            self.assertDigest(
                img, '6d04846ec7d263710897e6b6dabe4b79403917d7b280786d68bb960b4dc7d4ed')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, [])
            # Check that the working directory property has been properly configured.
            self.assertConfigEqual(img, 'WorkingDir', '/tmp')

    def test_tar_with_files_base(self):
        with TestImage('tar_with_files_base') as img:
            self.assertDigest(
                img, '596f8ce31445ba50efd929707c29ea9257baa7cab4ca04060f400e7944d3ca92')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                './asdf', './usr', './usr/bin',
                './usr/bin/miraclegrow'])

    def test_docker_tarball_base(self):
        with TestImage('docker_tarball_base') as img:
            self.assertDigest(
                img, '4540715e829ccec6b4801b42a4b4185f3a8ebd1bac5df20761f5c67f4119c9d5')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './foo'])

    def test_layers_with_docker_tarball_base(self):
        with TestImage('layers_with_docker_tarball_base') as img:
            self.assertDigest(
                img, 'ba89f7d89b59f7a09e209cd5aac533d9ff1f97c0f2313ea45e4c70b081fcd976')
            self.assertEqual(5, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './foo'])
            self.assertLayerNContains(
                img, 1, ['.', './three', './three/three'])
            self.assertLayerNContains(img, 2, ['.', './baz'])

    def test_base_with_entrypoint(self):
        with TestImage('base_with_entrypoint') as img:
            self.assertDigest(
                img, '732aa319e2bf017b174c182300fcd14b935df244c6539bf0aaa2ebd544b15126')
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
                img, '0f28b0372b8863f1aa05357ce2c1a97eb1e37ee658d23ede5343a52441916b03')
            self.assertEqual(3, len(img.fs_layers()))

            self.assertConfigEqual(img, 'Entrypoint', ['/bar'])
            self.assertConfigEqual(img, 'Cmd', ['arg1', 'arg2'])
            self.assertConfigEqual(
                img, 'ExposedPorts', {'8080/tcp': {}, '80/tcp': {}})

    def test_derivative_with_volume(self):
        with TestImage('derivative_with_volume') as img:
            self.assertDigest(
                img, '02cbd6ab6c0321e19967e10f56a033619f03b7749cd94ee0477df63492d1b103')
            self.assertEqual(2, len(img.fs_layers()))

            # Check that the topmost layer has the volumes exposed by the bottom
            # layer, and itself.
            self.assertConfigEqual(img, 'Volumes', {
                '/asdf': {}, '/blah': {}, '/logs': {}
            })

    def test_with_unix_epoch_creation_time(self):
        with TestImage('with_unix_epoch_creation_time') as img:
            self.assertDigest(
                img, '55e9615fe7b450c9962c520061b7d9bd1cc49f35d68629db8ac5389148b2eb0b')
            self.assertEqual(2, len(img.fs_layers()))
            cfg = json.loads(img.config_file())
            self.assertEqual('2009-02-13T23:31:30.119999885Z',
                             cfg.get('created', ''))

    def test_with_millisecond_unix_epoch_creation_time(self):
        with TestImage('with_millisecond_unix_epoch_creation_time') as img:
            self.assertDigest(
                img, '06e1facdeea3dee8185a6132a09087ff4de9f1509f560035094c2bc7486a7f34')
            self.assertEqual(2, len(img.fs_layers()))
            cfg = json.loads(img.config_file())
            self.assertEqual('2009-02-13T23:31:30.12345004Z',
                             cfg.get('created', ''))

    def test_with_rfc_3339_creation_time(self):
        with TestImage('with_rfc_3339_creation_time') as img:
            self.assertDigest(
                img, '8d8198c4d4b2af1ac3bf643f0a35744a35e1c19040229b23e0f2e496a28436b5')
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
                img, '1f74dcf381e204e4347c681460e1620104b7bbf4312a08c02e189e2cb95487b1')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertConfigEqual(
                img, 'Env', ['bar=blah blah blah', 'foo=/asdf'])

    def test_layers_with_env(self):
        with TestImage('layers_with_env') as img:
            self.assertDigest(
                img, 'c8b7a7bd8519006146f056c0dbd914e9d91840d4155fd6d84bb159337d1a4504')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertConfigEqual(
                img, 'Env', [u'PATH=$PATH:/tmp/a:/tmp/b:/tmp/c', u'a=b', u'x=y'])

    def test_dummy_repository(self):
        # We allow users to specify an alternate repository name instead of 'bazel/'
        # to prefix their image names.
        name = 'gcr.io/dummy/%s:dummy_repository' % TEST_DATA_TARGET_BASE
        with TestBundleImage('dummy_repository', name) as img:
            self.assertDigest(
                img, '9ad95debf6ef9a6077302c9752af772559f69d95f70aab16e603efc03dc0dbf6')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './foo'])

    def test_with_double_env(self):
        with TestImage('with_double_env') as img:
            self.assertDigest(
                img, '24de5c8d60ea4a3f67d4b953d53f918742c863d1b7edf03b1e4f97652a0ed283')
            self.assertEqual(3, len(img.fs_layers()))
            self.assertConfigEqual(img, 'Env', [
                'bar=blah blah blah',
                'baz=/asdf blah blah blah',
                'foo=/asdf'])

    def test_with_label(self):
        with TestImage('with_label') as img:
            self.assertDigest(
                img, '43f1870b2bbf25c12b8faad4a21d73554e7550f1db289b413b70f4a83f04c0cd')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertConfigEqual(img, 'Labels', {
                'com.example.bar': '{"name": "blah"}',
                'com.example.baz': 'qux',
                'com.example.foo': '{"name": "blah"}',
            })

    def test_with_double_label(self):
        with TestImage('with_double_label') as img:
            self.assertDigest(
                img, 'd4b9f98bfc526b8d1454bd72fabace51611dbd7a9b6b92b038a395c9bea60e99')
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
                img, '4c5b15d95197a2b476448125e68c8a2299b09fb77c5cb700bc64135630234917')
            self.assertEqual(2, len(img.fs_layers()))
            self.assertConfigEqual(img, 'User', 'nobody')

    def test_data_path(self):
        # Without data_path = "." the file will be inserted as `./test`
        # (since it is the path in the package) and with data_path = "."
        # the file will be inserted relatively to the testdata package
        # (so `./test/test`).
        with TestImage('no_data_path_image') as img:
            self.assertDigest(
                img, '46f7757c372468a48200f2c99e89bca59921f2298216fb8612faad24c446ee32')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './test'])
        with TestImage('data_path_image') as img:
            self.assertDigest(
                img, 'f4f697840d586638cc5f6e0bb85e8b531a28d231aa6ddee38087cc78affe54b7')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, ['.', './test', './test/test'])

        # With an absolute path for data_path, we should strip that prefix
        # from the files' paths. Since the testdata images are in
        # //testdata and data_path is set to
        # "/tools/build_defs", we should have `docker` as the top-level
        # directory.
        with TestImage('absolute_data_path_image') as img:
            self.assertDigest(
                img, '561fe9d52d073bf01590f08764d73da92230c908885915dee773357070a94901')
            self.assertEqual(1, len(img.fs_layers()))
            self.assertTopLayerContains(img, [
                '.', './testdata', './testdata/test', './testdata/test/test'])
            # With data_path = "/", we expect the entire path from the repository
            # root.
        with TestImage('root_data_path_image') as img:
            self.assertDigest(
                img, '561fe9d52d073bf01590f08764d73da92230c908885915dee773357070a94901')
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
                img, '4c5b15d95197a2b476448125e68c8a2299b09fb77c5cb700bc64135630234917')
        with TestBundleImage('bundle_test', 'docker.io/ubuntu:latest') as img:
            self.assertDigest(
                img, '732aa319e2bf017b174c182300fcd14b935df244c6539bf0aaa2ebd544b15126')
            self.assertEqual(1, len(img.fs_layers()))
        with TestBundleImage(
                'bundle_test', 'us.gcr.io/google-appengine/base:fresh') as img:
            self.assertDigest(
                img, '522197bc5a7d2cff9ce3821b8eb379c285af473af065860654ce9a374c407212')
            self.assertEqual(2, len(img.fs_layers()))
        with TestBundleImage(
                'bundle_test', 'gcr.io/google-containers/pause:2.0') as img:
            self.assertDigest(
                img, '24de5c8d60ea4a3f67d4b953d53f918742c863d1b7edf03b1e4f97652a0ed283')
            self.assertEqual(3, len(img.fs_layers()))

    def test_with_stamped_label(self):
        with TestImage('with_stamp_label') as img:
            self.assertEqual(2, len(img.fs_layers()))
            self.assertConfigEqual(
                img, 'Labels', {'BUILDER': STAMP_DICT['BUILD_USER']})

    def test_pause_based(self):
        with TestImage('pause_based') as img:
            self.assertDigest(
                img, 'ee4d1a868d5d69131af85b5106e5bf6e35243c39b0b6e59a8c7b0b1caac4c27e')
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
                img, '46014ba1cefa362387c428c36ca5afd81cae169a7c277e01ac5f12b410198007')
            self.assertEqual(3, len(img.fs_layers()))

    def test_with_passwd(self):
        with TestImage('with_passwd') as img:
            self.assertDigest(
                img, '803022993d158f7927176a1f490547775640c5b71aa3ce0bb8ace5706d3142f4')
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
                img, '20be1ce9d44fd90a431edf37aee85b71d4bc6540d9a82880c9dd0719f4e6fccb')
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
                img, 'a9ae91bd9dbd684f47b14a41c9a833b3191c49c5ccb950c20c81b08a8b3b4e18')
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
                img, 'aa82a3f747f2f5ecdd649d1f03c9480e9f16f17e9bdeaffcb9c490dad5d2e1fa')
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
                img, '4dce65b210d6c31ad6c3efd9e703446dcb9d53cee1f7528df90467b39f24d050')
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
                './app/testdata/nodejs_image_binary.runfiles/build_bazel_rules_nodejs/internal/linker/runfiles_helper.js',
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
