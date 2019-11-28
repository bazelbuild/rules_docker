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
import httplib2
import time

from containerregistry.client import docker_creds
from containerregistry.client import docker_name
from containerregistry.client.v2_2 import docker_image

parser = argparse.ArgumentParser(
    description=('Synthesize a .bzl file containing the digests '
                 'for a given repository.'))

parser.add_argument('--repository', action='store', required=True,
                    help=('The repository for which to resolve tags.'))

parser.add_argument('--output', action='store', required=True,
                    help='The output file to which we write the values.')


def main():
  args = parser.parse_args()

  creds = docker_creds.Anonymous()
  transport = httplib2.Http()

  repo = docker_name.Repository(args.repository)

  latest = docker_name.Tag(str(repo) + ":latest")
  with docker_image.FromRegistry(latest, creds, transport) as img:
    latest_digest = img.digest()

  debug = docker_name.Tag(str(repo) + ":debug")
  with docker_image.FromRegistry(debug, creds, transport) as img:
    if img.exists():
      debug_digest = img.digest()
    else:
      debug_digest = latest_digest

  with open(args.output, 'w') as f:
    f.write("""\
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
\"\"\" Generated file with dependencies for language rule.\"\"\"

# !!!! THIS IS A GENERATED FILE TO NOT EDIT IT BY HAND !!!!
#
# To regenerate this file, run ./update_deps.sh from the root of the
# git repository.

DIGESTS = {{
    # "{debug_tag}" circa {date}
    "debug": "{debug}",
    # "{latest_tag}" circa {date}
    "latest": "{latest}",
}}
""".format(
    debug_tag=debug,
    debug=debug_digest,
    latest_tag=latest,
    latest=latest_digest,
    date=time.strftime("%Y-%m-%d %H:%M %z")))

if __name__ == '__main__':
  main()
