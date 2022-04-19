#!/usr/bin/env bash
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

function guess_runfiles() {
    if [ -d ${BASH_SOURCE[0]}.runfiles ]; then
        # Runfiles are adjacent to the current script.
        echo "$( cd ${BASH_SOURCE[0]}.runfiles && pwd )"
    else
        # The current script is within some other script's runfiles.
        mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        echo $mydir | sed -e 's|\(.*\.runfiles\)/.*|\1|'
    fi
}

RUNFILES="${PYTHON_RUNFILES:-$(guess_runfiles)}"

DOCKER="%{docker_tool_path}"
DOCKER_FLAGS="%{docker_flags}"

if [[ -z "${DOCKER}" ]]; then
    echo >&2 "error: docker not found; do you need to manually configure the docker toolchain?"
    exit 1
fi

# Create temporary files in which to record things to clean up.
TEMP_FILES="$(mktemp -t 2>/dev/null || mktemp -t 'rules_docker_files')"
TEMP_IMAGES="$(mktemp -t 2>/dev/null || mktemp -t 'rules_docker_images')"
function cleanup() {
  cat "${TEMP_FILES}" | xargs rm -rf> /dev/null 2>&1 || true
  cat "${TEMP_IMAGES}" | xargs "${DOCKER}" ${DOCKER_FLAGS} rmi > /dev/null 2>&1 || true

  rm -rf "${TEMP_FILES}"
  rm -rf "${TEMP_IMAGES}"
}
trap cleanup EXIT


function load_legacy() {
  local tarball="${RUNFILES}/$1"

  # docker load has elision of preloaded layers built in.
  echo "Loading legacy tarball base $1..."
  "${DOCKER}" ${DOCKER_FLAGS} load -i "${tarball}"
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
  tar c config.json manifest.json | "${DOCKER}" ${DOCKER_FLAGS} load 2>/dev/null | cut -d':' -f 2- >> "${TEMP_IMAGES}"
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


  PYTHON="python"
  if command -v python3 &>/dev/null; then
      PYTHON="python3"
  fi

  TOTAL_DIFF_IDS=($(cat "${name}" | $PYTHON -mjson.tool | \
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
  tar cPh "${MISSING[@]}" | "${DOCKER}" ${DOCKER_FLAGS} load
}

function tag_layer() {
  local name="$(cat "${RUNFILES}/$2")"

  local TAG="$1"
  echo "Tagging ${name} as ${TAG}"
  "${DOCKER}" ${DOCKER_FLAGS} tag sha256:${name} ${TAG}
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

# An optional "docker run" statement for invoking a loaded container.
# This is not executed if the single argument --norun is passed or
# no run_statements are generated (in which case, 'run' is 'False').
if [[ "%{run}" == "True" ]]; then
  docker_args=()
  container_args=()

  # Search remaining params looking for docker and container args.
  #
  # It is assumed that they will follow the pattern:
  # [dockerargs...] -- [container args...]
  #
  # "--norun" is treated as a "virtual" additional parameter to
  # "docker run", since it cannot conflict with any "docker run"
  # arguments.  If "--norun" needs to be passed to the container,
  # it can be safely placed after "--".
  while test $# -gt 0
  do
      case "$1" in
          --norun) # norun as a "docker run" option means exit
              exit
              ;;
          --) # divider between docker and container args
              shift
              container_args=("$@")
              break
              ;;
          *)  # potential "docker run" option
              docker_args+=("$1")
              shift
              ;;
      esac
  done

  # Once we've loaded the images for all layers, we no longer need the temporary files on disk.
  # We can clean up before we exec docker, since the exit handler will no longer run.
  cleanup

  # Bash treats empty arrays as unset variables for the purposes of `set -u`, so we only
  # conditionally add these arrays to our args.
  args=(%{run_statement})
  if [[ ${#docker_args[@]} -gt 0 ]]; then
    args+=("${docker_args[@]}")
  fi
  args+=("%{run_tag}")
  if [[ ${#container_args[@]} -gt 0 ]]; then
    args+=("${container_args[@]}")
  fi

  # This generated and injected by docker_*.
  eval exec "${args[@]}"
fi
