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

# List all images identifier (only the identifier) from the local
# docker registry.
IMAGES="$("${DOCKER}" images -aq)"
IMAGE_LEN=$(for i in $IMAGES; do echo -n $i | wc -c; done | sort -g | head -1 | xargs)

[ -n "$IMAGE_LEN" ] || IMAGE_LEN=64

function incr_load() {
  # Load a layer if and only if the layer is not in "$IMAGES", that is
  # in the local docker registry.
  name=$(cat ${RUNFILES}/$1)

  if (echo "$IMAGES" | grep -q ^${name:0:$IMAGE_LEN}$); then
    echo "Skipping $name, already loaded."
  else
    echo "Loading $name..."
    "${DOCKER}" load -i ${RUNFILES}/$2
  fi
}

function tag_layer() {
  name=$(cat ${RUNFILES}/$2)

  TAG="$1"
  echo "Tagging ${name} as ${TAG}"
  "${DOCKER}" tag sha256:${name} ${TAG}
}

function read_variables() {
  local file=${RUNFILES}/$1
  local new_file=$(mktemp)
  trap "rm -f ${new_file}" EXIT

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

