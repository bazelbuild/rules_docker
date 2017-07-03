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

# Check we are using GNU tar as this script relies on some impl specifics
# e.g. on a Mac the default is a BSD variant which will bork
tar --version | grep 'GNU' >/dev/null 2>&1
if [ ! $? -eq 0 ]; then
  echo "Error: GNU tar needs to be installed."
  echo "If you are on a Mac, install Homebrew then..."
  echo "  brew install gnu-tar --with-default-names"
  exit 1
fi

RUNFILES="${PYTHON_RUNFILES:-${BASH_SOURCE[0]}.runfiles}"

DOCKER="${DOCKER:-docker}"

function list_diffids() {
  for image in $("${DOCKER}" images -aq 2> /dev/null);
  do
    for entry in $("${DOCKER}" inspect -f '{{json .RootFS.Layers}}' "${image}");
    do
      echo -n $entry | python -mjson.tool | grep sha256 | cut -d'"' -f 2 | cut -d':' -f 2
    done
  done
}

# Fetch the diff ids of the layers loaded in the docker daemon already
IMAGES=$(list_diffids | sort | uniq)
IMAGE_LEN=$(for i in $IMAGES; do echo -n $i | wc -c; done | sort -g | head -1 | xargs)

[ -n "$IMAGE_LEN" ] || IMAGE_LEN=64

# Create temporary files in which to record things to clean up.
TEMP_FILES="$(mktemp -t 2>/dev/null || mktemp -t 'rules_docker_files')"
TEMP_IMAGES="$(mktemp -t 2>/dev/null || mktemp -t 'rules_docker_images')"
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

function join_by() {
  local IFS="$1"
  shift
  echo "$*"
}

function sequence_exists() {
  local diff_ids="$@"
  cat > config.json <<EOF
{
    "architecture": "amd64",
    "author": "Bazel",
    "config": {},
    "created": "0001-01-01T00:00:00Z",
    "history": [
        {
            "author": "Bazel",
            "created": "0001-01-01T00:00:00Z",
            "created_by": "bazel build ..."
        }
    ],
    "os": "linux",
    "rootfs": {
        "diff_ids": [$(join_by , ${diff_ids[@]})],
        "type": "layers"
    }
}
EOF

  cat > manifest.json <<EOF
[{
   "Config": "config.json",
   "Layers": [$(join_by , ${diff_ids[@]})],
   "RepoTags": []
}]
EOF

  set -o pipefail
  tar c config.json manifest.json | "${DOCKER}" load | cut -d':' -f 2- >> "${TEMP_IMAGES}" 2>/dev/null
}

function find_diffbase() {
  local name="$1"
  shift

  NEW_DIFF_IDS=()
  while test $# -gt 0
  do
    local diff_id="$(cat "${RUNFILES}/$1")"
    # Throwaway the layer, we only want diff id.
    shift 2

    NEW_DIFF_IDS+=("${diff_id}")
  done

  TOTAL_DIFF_IDS=($(cat "${name}" | python -mjson.tool | \
      grep -E '^ +"sha256:' | cut -d'"' -f 2 | cut -d':' -f 2))

  LEGACY_COUNT=$((${#TOTAL_DIFF_IDS[@]} - ${#NEW_DIFF_IDS[@]}))
  echo "${TOTAL_DIFF_IDS[@]:0:${LEGACY_COUNT}}"
}

function import_config() {
  # Create an image from the image configuration file.
  local name="${RUNFILES}/$1"
  shift 1

  local tmp_dir="$(mktemp -d)"
  echo "${tmp_dir}" >> "${TEMP_FILES}"

  cd "${tmp_dir}"

  # Docker elides layer reads from the tarball when it
  # already has a copy of the layer with the same basis
  # as it has within the tarball.  This means that once
  # we have found the lowest layer in our image of which
  # Docker is unaware we must load all of the remaining
  # layers.  So to determine existence, iterate through
  # the layers attempting to load the image without it's
  # tarball.  As soon as one fails, break and synthesize
  # a "docker save" tarball of all of the remaining layers.

  # Find the cut-off point of layers we may
  # already know about, and setup out arrays.
  DIFF_IDS=()
  ALL_QUOTED=()
  for diff_id in $(find_diffbase "${name}" "$@");
  do
    DIFF_IDS+=("\"sha256:${diff_id}\"")
    ALL_QUOTED+=("\"${diff_id}.tar\"")
  done

  # Starting from our legacy diffbase, figure out which
  # additional layers the Docker daemon already has.
  while test $# -gt 0
  do
    local diff_id="$(cat "${RUNFILES}/$1")"
    local layer="${RUNFILES}/$2"

    DIFF_IDS+=("\"sha256:${diff_id}\"")

    if ! sequence_exists "${DIFF_IDS[@]}"; then
      # This sequence of diff-ids has not been seen,
      # so we must start by making this layer part of
      # the tarball we load.
      break
    fi

    ALL_QUOTED+=("\"${diff_id}.tar\"")
    shift 2
  done

  # Set up the list of layers we actually need to load,
  # from the cut-off established above.
  MISSING=()
  while test $# -gt 0
  do
    local diff_id="$(cat "${RUNFILES}/$1")"
    local layer="${RUNFILES}/$2"
    shift 2

    ALL_QUOTED+=("\"${diff_id}.tar\"")

    # Only create the link if it doesn't exist.
    # Only add files to MISSING once.
    if [ ! -f "${diff_id}.tar" ]; then
      ln -s "${layer}" "${diff_id}.tar"
      MISSING+=("${diff_id}.tar")
    fi
  done

  cp "${name}" config.json
  cat > manifest.json <<EOF
[{
   "Config": "config.json",
   "Layers": [$(join_by , ${ALL_QUOTED[@]})],
   "RepoTags": []
}]
EOF

  MISSING+=("config.json" "manifest.json")

  # We minimize reads / writes by symlinking the layers above
  # and then streaming exactly the layers we've established are
  # needed into the Docker daemon.
  tar --create --absolute-names --dereference \
      "${MISSING[@]}" | tee image.tar | "${DOCKER}" load
}

function tag_layer() {
  local name="$(cat "${RUNFILES}/$2")"

  local TAG="$1"
  echo "Tagging ${name} as ${TAG}"
  "${DOCKER}" tag sha256:${name} ${TAG}
}

function read_variables() {
  local file="${RUNFILES}/$1"
  local new_file="$(mktemp -t 2>/dev/null || mktemp -t 'rules_docker_new')"
  echo "${new_file}" >> "${TEMP_FILES}"

  # Rewrite the file from Bazel for the form FOO=...
  # to a form suitable for sourcing into bash to expose
  # these variables as substitutions in the tag statements.
  sed -E "s/^([^ ]+) (.*)\$/export \\1='\\2'/g" < ${file} > ${new_file}
  source ${new_file}
}

# Statements initializing stamp variables.
%{stamp_statements}

# List of 'import_config' statements for all images.
# This generated and injected by docker_*.
%{load_statements}

# List of 'tag_layer' statements for all tags.
# This generated and injected by docker_*.
%{tag_statements}
