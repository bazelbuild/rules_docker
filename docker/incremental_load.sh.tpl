#!/bin/bash
#
# Copyright 2015 The Bazel Authors. All rights reserved.
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

set -eu

# This is a generated file that loads all docker layers built by "docker_build".

RUNFILES="${PYTHON_RUNFILES:-${BASH_SOURCE[0]}.runfiles}"

DOCKER="${DOCKER:-docker}"

# Fetch the diff ids of the layers loaded in the docker daemon already
IMAGES=$(${DOCKER} inspect $(${DOCKER} images -aq) |& \
  grep sha256 | grep -v Id | cut -d'"' -f 2 | cut -d':' -f 2 | \
  sort | uniq)
IMAGE_LEN=$(for i in $IMAGES; do echo -n $i | wc -c; done | sort -g | head -1 | xargs)

[ -n "$IMAGE_LEN" ] || IMAGE_LEN=64

# Create temporary files in which to record things to clean up.
TEMP_FILES=$(mktemp)
TEMP_IMAGES=$(mktemp)
function cleanup() {
  cat "${TEMP_FILES}" | xargs rm -rf> /dev/null 2>&1 || true
  cat "${TEMP_IMAGES}" | xargs "${DOCKER}" rmi > /dev/null 2>&1 || true

  rm -rf "${TEMP_FILES}"
  rm -rf "${TEMP_IMAGES}"
}
trap cleanup EXIT


function load_legacy() {
  local tarball="${RUNFILES}/$1"

  # docker load has elision of preloaded layers built in.
  echo "Loading legacy tarball base $1..."
  "${DOCKER}" load -i "${tarball}"
}

function import_layer() {
  # Load a layer if and only if the layer is not in "$IMAGES", that is
  # in the local docker registry.
  local name=$(cat ${RUNFILES}/$1)

  if (echo "$IMAGES" | grep -q ^${name:0:$IMAGE_LEN}$); then
    echo "Skipping ${name}, already loaded."
  else
    echo "Importing ${name}..."
    TEMP_IMAGE=$(cat ${RUNFILES}/$2 | "${DOCKER}" import -)
    echo "${TEMP_IMAGE}" >> "${TEMP_IMAGES}"
  fi
}

function import_config() {
  # Create an image from the image configuration file.
  local name=${RUNFILES}/$1
  local diff_id=$(cat ${RUNFILES}/$2)
  local layer=${RUNFILES}/$3

  local tmp_dir=$(mktemp -d)
  echo "${tmp_dir}" >> "${TEMP_FILES}"

  cd "${tmp_dir}"
  cp "${name}" the-image.json
  cp "${layer}" "${diff_id}.tar"
  local parent_layers=$(cat the-image.json | python -mjson.tool | \
    grep sha256 | grep "," | cut -d'"' -f 2 | cut -d':' -f 2)

  cat > manifest.json <<EOF
[{
   "Config": "the-image.json",
   "Layers": [$(
for x in ${parent_layers}
do
  # We must follow a consistent scheme here in case it overlaps
  # with the final layer.
  echo -n "\"$x.tar\","
done
echo -n "\"${diff_id}.tar\""
)
   ],
   "RepoTags": []
}]
EOF
  tar cf image.tar the-image.json "${diff_id}.tar" manifest.json
  docker load -i image.tar
}

function tag_layer() {
  local name=$(cat ${RUNFILES}/$2)

  local TAG="$1"
  echo "Tagging ${name} as ${TAG}"
  "${DOCKER}" tag sha256:${name} ${TAG}
}

function read_variables() {
  local file=${RUNFILES}/$1
  local new_file=$(mktemp)
  echo "${new_file}" >> "${TEMP_FILES}"

  # Rewrite the file from Bazel for the form FOO=...
  # to a form suitable for sourcing into bash to expose
  # these variables as substitutions in the tag statements.
  sed -E "s/^([^ ]+) (.*)\$/export \\1='\\2'/g" < ${file} > ${new_file}
  source ${new_file}
}

# Statements initializing stamp variables.
%{stamp_statements}

# List of 'incr_load' statements for all layers.
# This generated and injected by docker_build.
%{load_statements}

# List of 'tag_layer' statements for all tags.
# This generated and injected by docker_build.
%{tag_statements}
