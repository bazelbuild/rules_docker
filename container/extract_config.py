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
"""A trivial binary to extract the v2.2 config file."""

import argparse

from containerregistry.client.v2_2 import docker_image

parser = argparse.ArgumentParser(
    description='Extract the v2.2 config from a Docker image tarball.')

parser.add_argument('--tarball', action='store', required=True,
                    help=('The Docker image tarball from which to '
                          'extract the image name.'))

parser.add_argument('--output', action='store', required=True,
                    help='The output file to which we write the config.')

parser.add_argument('--manifestoutput', action='store', required=True,
                    help='The output file to which we write the manifest.')

# Main program to create a docker image. It expect to be run with:
#   extract_config --tarball=image.tar \
#       --output=output.config \
def main():
  args = parser.parse_args()

  with docker_image.FromTarball(args.tarball) as img:
    with open(args.output, 'w') as f:
      f.write(img.config_file())
    with open(args.manifestoutput, 'w') as f:
      f.write(img.manifest())


if __name__ == '__main__':
  main()
