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

if __name__ == '__main__':
  unittest.main()
