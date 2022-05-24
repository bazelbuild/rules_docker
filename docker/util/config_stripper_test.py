# Copyright 2017 The Bazel Authors. All rights reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Lint as: python3
"""Tests for config_stripper."""

import os
import unittest
import tarfile
import json

from docker.util.config_stripper import strip_tar


class ConfigStripperTest(unittest.TestCase):
    def test_image_with_symlinked_layers(self):
        # Ensure the config stripper can strip a tar with symlinked layers.
        # https://github.com/bazelbuild/rules_docker/issues/1104.
        img_tar = os.path.join(
            os.environ['TEST_SRCDIR'],
            'io_bazel_rules_docker',
            'docker/util/testdata/image_with_symlinked_layer.tar')
        out_tar = os.path.join(
            os.environ["TEST_TMPDIR"],
            "test_image_with_symlinked_layers_out.tar")
        strip_tar(img_tar, out_tar)
        if not os.path.exists(out_tar):
            self.fail(
                "Config stripper did not produce stripped tarball {}".format(
                    out_tar))

        # Unpack the output.
        test_image_unpacked = os.path.join(
            os.environ["TEST_TMPDIR"],
            "test_image_unpacked")
        os.mkdir(test_image_unpacked)
        with tarfile.open(name=out_tar, mode='r') as it:
            it.extractall(test_image_unpacked)

        # Check the generated manifest.
        mf_path = os.path.join(test_image_unpacked, 'manifest.json')
        with open(mf_path, 'r') as mf:
            manifest = json.load(mf)
        expected_manifest = [{'Config': 'sha256:e23c58d96cd9b792b2c81802aff2df452dda4eaf8721e3384e00c6f9454d3444',
                              'Layers': ['sha256:85cea451eec057fa7e734548ca3ba6d779ed5836a3f9de14b8394575ef0d7d8e',
                                         'sha256:85cea451eec057fa7e734548ca3ba6d779ed5836a3f9de14b8394575ef0d7d8e'],
                              'RepoTags': ['bazel:small_base_2']}]
        self.assertEquals(manifest, expected_manifest)

        # Check the generated legacy repositories file.
        repositories_path = os.path.join(test_image_unpacked, 'repositories')
        with open(repositories_path, 'r') as rf:
            repositories = json.load(rf)
        expected_repositories = {
            'bazel': {'small_base_2': 'sha256:85cea451eec057fa7e734548ca3ba6d779ed5836a3f9de14b8394575ef0d7d8e'}
        }
        self.assertEquals(repositories, expected_repositories)

if __name__ == '__main__':
    unittest.main()
