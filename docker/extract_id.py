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
"""A trivial binary to extract the v2.2/v1 IDs from a Docker image tarball."""

import argparse
import hashlib
import sys

from containerregistry.client.v2 import v1_compat
from containerregistry.client.v2_2 import docker_image
from containerregistry.client.v2_2 import v2_compat

parser = argparse.ArgumentParser(
    description='Extract the image ids from a Docker image tarball.')

parser.add_argument('--tarball', action='store', required=True,
                    help=('The Docker image tarball from which to '
                          'extract the image name.'))

parser.add_argument('--output_id', action='store', required=True,
                    help='The output file to which we write the id.')

parser.add_argument('--output_name', action='store', required=True,
                    help='The output file to which we write the name.')


# Main program to create a docker image. It expect to be run with:
#   extract_id --tarball=image.tar \
#       --output_id=output.id \
#       --output_name=output.name
def main():
  args = parser.parse_args()

  with docker_image.FromTarball(args.tarball) as v2_2_img:
    with open(args.output_id, 'w') as f:
      f.write(hashlib.sha256(v2_2_img.config_file()).hexdigest())

    with v2_compat.V2FromV22(v2_2_img) as v2_img:
      with v1_compat.V1FromV2(v2_img) as v1_img:
        with open(args.output_name, 'w') as f:
          f.write(v1_img.top())


if __name__ == '__main__':
  main()
