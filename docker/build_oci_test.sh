#!/bin/bash

# Copyright 2016 The Bazel Authors. All rights reserved.
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

# Unit tests for docker_build

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source ${DIR}/testenv.sh || { echo "testenv.sh not found!" >&2; exit 1; }

readonly PLATFORM="$(uname -s | tr 'A-Z' 'a-z')"
if [ "${PLATFORM}" = "darwin" ]; then
  readonly MAGIC_TIMESTAMP="$(date -r 0 "+%b %e  %Y")"
else
  readonly MAGIC_TIMESTAMP="$(date --date=@0 "+%F %R")"
fi

function EXPECT_CONTAINS() {
  local complete="${1}"
  local substring="${2}"
  local message="${3:-Expected '${substring}' not found in '${complete}'}"

  echo "${complete}" | grep -Fsq -- "${substring}" \
    || fail "$message"
}

function check_property() {
  local property="${1}"
  local tarball="${2}"
  local image="${3}"
  local expected="${4}"
  local test_data="${TEST_DATA_DIR}/${tarball}.tar"

  local config="$(tar xOf "${test_data}" "${image}.json")"

  # This would be much more accurate if we had 'jq' everywhere.
  EXPECT_CONTAINS "${config}" "\"${property}\": ${expected}"
}

function check_no_property() {
  local property="${1}"
  local tarball="${2}"
  local image="${3}"
  local test_data="${TEST_DATA_DIR}/${tarball}.tar"

  tar xOf "${test_data}" "${image}.json" >$TEST_log
  expect_not_log "\"${property}\":"
}

function check_entrypoint() {
  input="$1"
  shift
  check_property Entrypoint "${input}" "${@}"
}

function check_cmd() {
  input="$1"
  shift
  check_property Cmd "${input}" "${@}"
}

function check_ports() {
  input="$1"
  shift
  check_property ExposedPorts "${input}" "${@}"
}

function check_volumes() {
  input="$1"
  shift
  check_property Volumes "${input}" "${@}"
}

function check_env() {
  input="$1"
  shift
  check_property Env "${input}" "${@}"
}

function check_label() {
  input="$1"
  shift
  check_property Label "${input}" "${@}"
}

function check_workdir() {
  input="$1"
  shift
  check_property WorkingDir "${input}" "${@}"
}

function check_user() {
  input="$1"
  shift
  check_property User "${input}" "${@}"
}

function check_images() {
  local input="$1"
  shift 1
  local expected_images=(${*})
  local test_data="${TEST_DATA_DIR}/${input}.tar"

  local manifest="$(tar xOf "${test_data}" "manifest.json")"
  local manifest_images=(
    $(echo "${manifest}" | grep -Eo '"Config":[[:space:]]*"[^"]+"' \
      | grep -Eo '[0-9a-f]{64}'))

  local manifest_parents=(
    $(echo "${manifest}" | grep -Eo '"Parent":[[:space:]]*"[^"]+"' \
      | grep -Eo '[0-9a-f]{64}'))

  # Verbose output for testing.
  echo Expected: "${expected_images[@]}"
  echo Actual: "${manifest_images[@]}"
  echo Parents: "${manifest_parents[@]}"

  check_eq "${#expected_images[@]}" "${#manifest_images[@]}"

  local index=0
  while [ "${index}" -lt "${#expected_images[@]}" ]
  do
    # Check that the nth sorted layer matches
    check_eq "${expected_images[$index]}" "${manifest_images[$index]}"

    index=$((index + 1))
  done

  # Check that the image contains its predecessor as its parent in the manifest.
  check_eq "${#manifest_parents[@]}" "$((${#manifest_images[@]} - 1))"

  local index=0
  while [ "${index}" -lt "${#manifest_parents[@]}" ]
  do
    # Check that the nth sorted layer matches
    check_eq "${manifest_parents[$index]}" "${manifest_images[$index]}"

    index=$((index + 1))
  done
}

# The bottom manifest entry must contain all layers in order
function check_image_manifest_layers() {
  local input="$1"
  shift 1
  local expected_layers=(${*})
  local test_data="${TEST_DATA_DIR}/${input}.tar"

  local manifest="$(tar xOf "${test_data}" "manifest.json")"
  local manifest_layers=(
    $(echo "${manifest}" | grep -Eo '"Layers":[[:space:]]*\[[^]]+\]' \
      | grep -Eo '\[.+\]' | tail -n 1 | grep -Eo '[0-fa-z]{64}'))

  # Verbose output for testing.
  echo Expected: "${expected_layers[@]}"
  echo Actual: "${manifest_layers[@]}"

  check_eq "${#expected_layers[@]}" "${#manifest_layers[@]}"

  local index=0
  while [ "${index}" -lt "${#expected_layers[@]}" ]
  do
    # Check that the nth sorted layer matches
    check_eq "${expected_layers[$index]}" "${manifest_layers[$index]}"

    index=$((index + 1))
  done
}

function check_layers_aux() {
  local input="$1"
  shift 1
  local expected_layers=(${*})

  local expected_layers_sorted=(
    $(for i in ${expected_layers[*]}; do echo $i; done | sort)
  )
  local test_data="${TEST_DATA_DIR}/${input}.tar"

  # Verbose output for testing.
  tar tvf "${test_data}"

  local actual_layers=(
    $(tar tf ${test_data} | sort \
      | cut -d'/' -f 1 | grep -E '^[0-9a-f]+$' | sort | uniq))

  # Verbose output for testing.
  echo Expected: "${expected_layers_sorted[@]}"
  echo Actual: "${actual_layers[@]}"

  check_eq "${#expected_layers[@]}" "${#actual_layers[@]}"

  local index=0
  while [ "${index}" -lt "${#expected_layers[@]}" ]
  do
    # Check that the nth sorted layer matches
    check_eq "${expected_layers_sorted[$index]}" "${actual_layers[$index]}"

    # Grab the ordered layer and check it.
    local layer="${expected_layers[$index]}"

    # Verbose output for testing.
    echo Checking layer: "${layer}"

    local listing="$(tar xOf "${test_data}" "${layer}/layer.tar" | tar tv)"

    # Check that all files in the layer, if any, have the magic timestamp
    check_eq "$(echo "${listing}" | grep -Fv "${MAGIC_TIMESTAMP}" || true)" ""

    index=$((index + 1))
  done
}

function check_layers() {
  local input="$1"
  shift
  check_layers_aux "$input" "$@"
  check_image_manifest_layers "$input" "$@"
}

function test_gen_image() {
  grep -Fsq "./gen.out" "$TEST_DATA_DIR/gen_image.tar" \
    || fail "'./gen.out' not found in '$TEST_DATA_DIR/gen_image.tar'"
}

function test_dummy_repository() {
  local layer="7771c123a312b2d11b841ac88b8d349fd472288e019d90e0298177c237e8548d"
  local test_data="${TEST_DATA_DIR}/dummy_repository.tar"
  check_layers_aux "dummy_repository" "$layer"
}

function test_files_base() {
  check_layers "files_base" \
    "ef2df17c7d29bc9716c86a40311a1c026d7f328374e69e003e7af64f6e148a1b"
}

function test_files_with_files_base() {
  check_layers "files_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "7d3922332e0b0720caa78a5fac5df60f31ce63a8f7bcbf1369cf50cf0f2eec89"
}

function test_tar_base() {
  check_layers "tar_base" \
    "823a94eba6bd535a1badc72f7258e8f4d96d6ff636e3c4c409128a6de1e8df39"

  # Check that this layer doesn't have any entrypoint data by looking
  # for *any* entrypoint.
  check_no_property "Entrypoint" "tar_base" \
    "9fec194fd32c03350d6a6e60ee8ed7862471e8817aaa310306d9be6242b05d20"
}

function test_tar_with_tar_base() {
  check_layers "tar_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "01d70f1c84473e80c71fb1392aa605c834bf27f23ac78d6f8292348770ba9051"
}

function test_directory_with_tar_base() {
  check_layers "directory_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "9888a583af14e1d51b2bc18003dab010a3781aa0d85603fa1b952f693a76ffb1"
}

function test_files_with_tar_base() {
  check_layers "files_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "b0b24d40d4d3492d6a8115c595c9ae225491ba35ea9f37121b440733275d1af1"
}

function test_workdir_with_tar_base() {
  check_layers "workdir_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "5915f95557288f70c1b852a407287431b77598ef4212a177d9aa7fd895c1d532"
}

function test_tar_with_files_base() {
  check_layers "tar_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "e9dcbb6979d1c16c832f3a2879788a123da3b81c98a98ef2ba7f44e73da1edc8"
}

function test_base_with_entrypoint() {
  check_layers "base_with_entrypoint" \
    "2296fe5c1a9cf075fa2dea939d51ee263dd8c9b8f91030e07f56bc27bffa1ab5"

  check_entrypoint "base_with_entrypoint" \
    "d59ab78d94f88b906227b8696d3065b91c71a1c6045d5103f3572c1e6fe9a1a9" \
    '["/bar"]'

  # Check that the base layer has a port exposed.
  check_ports "base_with_entrypoint" \
    "d59ab78d94f88b906227b8696d3065b91c71a1c6045d5103f3572c1e6fe9a1a9" \
    '{"8080/tcp": {}}'
}

function test_derivative_with_shadowed_cmd() {
  check_layers "derivative_with_shadowed_cmd" \
    "924348d4f092ab4b3a17e14c68d8e42e2c6564bde6d5d72f2e8fb66ac1bfe20a" \
    "9c7d54bff967bae78b7b2011d1e68c62e7b2f4eba63925df027d8c8172a3bb79"
}

function test_derivative_with_cmd() {
  check_layers "derivative_with_cmd" \
    "924348d4f092ab4b3a17e14c68d8e42e2c6564bde6d5d72f2e8fb66ac1bfe20a" \
    "3ecdff6ae8d5240aa21295c0b425c2d1adb08e10bd10ce77f27d5896a72960e3" \
    "354cd9c43dd83f0aecf8d1091b61b7e7ea0c31b2079c8b7c9b2c14f7d989c4a0"

  check_images "derivative_with_cmd" \
    "d3ea6e7cfc3e182a8ca43081db1e145f1bee8c5da5627639800c76abf61b5165"

  check_entrypoint "derivative_with_cmd" \
    "d3ea6e7cfc3e182a8ca43081db1e145f1bee8c5da5627639800c76abf61b5165" \
    '["/bar"]'
}

function test_derivative_with_volume() {
  check_layers "derivative_with_volume" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "f69c3d81f60ad3efc8ee66f7c6241bf2450bb7fb8b14d12164b5f57b64b3086b"

  check_images "derivative_with_volume" \
    "c872bf3f4c7eb5a01ae7ad6fae4c25e86ff2923bb1fe29be5edcdff1b31ed71a"

  # Check that the topmost layer has the ports exposed by the bottom
  # layer, and itself.
  check_volumes "derivative_with_volume" \
    "c872bf3f4c7eb5a01ae7ad6fae4c25e86ff2923bb1fe29be5edcdff1b31ed71a" \
    '{"/asdf": {}, "/blah": {}, "/logs": {}}'
}

# TODO(mattmoor): Needs a visibility change.
# function test_generated_tarball() {
#   check_layers "generated_tarball" \
#     "54b8328604115255cc76c12a2a51939be65c40bf182ff5a898a5fb57c38f7772"
# }

function test_with_env() {
  check_layers "with_env" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "958057ce6cd518030ed84548a16d72f1c3d168c71222368e0bbfd3e5b0dc3725"

  check_env "with_env" \
    "87c0d91841f92847ec6c183810f720e5926dba0652eb5d52a807366825dd21c7" \
    '["bar=blah blah blah", "foo=/asdf"]'
}

function test_with_double_env() {
  check_layers "with_double_env" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "a1eafb9b3f015fc28237bf9e10f9a6103dd9d29368f081952207fddcd1045833"

  # Check both the aggregation and the expansion of embedded variables.
  check_env "with_double_env" \
    "273d2a6cfc25001baf9d3f7c68770ec79a1671b8249d153e7611a4f80165ecda" \
    '["bar=blah blah blah", "baz=/asdf blah blah blah", "foo=/asdf"]'
}

function test_with_label() {
  check_layers "with_label" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "57438bbe887e61de6b535eda83047c45ee1f98e2bf50071358e617067ccb04aa"

  check_label "with_label" \
    "83c007425faff33ac421329af9f6444b7250abfc12c28f188b47e97fb715c006" \
    '["com.example.bar={\"name\": \"blah\"}", "com.example.baz=qux", "com.example.foo={\"name\": \"blah\"}"]'
}

function test_with_double_label() {
  check_layers "with_double_label" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "b14fe258f95cd176eef757a7343508f028cf568e0feb9fea677469742700534e"

  check_label "with_double_label" \
    "8cfc89c83adf947cd2c18c11579559f1f48cf375a20364ec79eb14d6580dbf75" \
    '["com.example.bar={\"name\": \"blah\"}", "com.example.baz=qux", "com.example.foo={\"name\": \"blah\"}", "com.example.qux={\"name\": \"blah-blah\"}"]'
}

function test_with_user() {
  check_layers "with_user" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "5f8e5f6593a746cb509459aee90b2ac9c64031db513e8a013ef6236c821e72a4"

  check_user "with_user" \
    "bd6666bdde7d4a837a0685d2861822507119f7f6e565acecbbbe93f1d0cc1974" \
    "\"nobody\""
}

function get_layer_listing() {
  local input=$1
  local layer=$2
  local test_data="${TEST_DATA_DIR}/${input}.tar"
  tar xOf "${test_data}" "${layer}/layer.tar" | tar t
}

function test_data_path() {
  local no_data_path_sha="de3853f68a7edad8a8adb83363652d0927d6a69c6ed790e85bf0048892134bbc"
  local data_path_sha="0ea8ce6cf08d60758c509295987232a41a9b07676533c6aae8d7608c85fb2b82"
  local absolute_data_path_sha="800edeae00c369c8caadf06a816014629f6144c857ee33facfb6ab82705d83ef"
  local root_data_path_sha="800edeae00c369c8caadf06a816014629f6144c857ee33facfb6ab82705d83ef"

  check_layers_aux "no_data_path_image" "${no_data_path_sha}"
  check_layers_aux "data_path_image" "${data_path_sha}"
  check_layers_aux "absolute_data_path_image" "${absolute_data_path_sha}"
  check_layers_aux "root_data_path_image" "${root_data_path_sha}"

  # Without data_path = "." the file will be inserted as `./test`
  # (since it is the path in the package) and with data_path = "."
  # the file will be inserted relatively to the testdata package
  # (so `./test/test`).
  check_eq "$(get_layer_listing "no_data_path_image" "${no_data_path_sha}")" \
    './
./test'
  check_eq "$(get_layer_listing "data_path_image" "${data_path_sha}")" \
    './
./test/
./test/test'

  # With an absolute path for data_path, we should strip that prefix
  # from the files' paths. Since the testdata images are in
  # //docker/testdata and data_path is set to
  # "/tools/build_defs", we should have `docker` as the top-level
  # directory.
  check_eq "$(get_layer_listing "absolute_data_path_image" "${absolute_data_path_sha}")" \
    './
./docker/
./docker/testdata/
./docker/testdata/test/
./docker/testdata/test/test'

  # With data_path = "/", we expect the entire path from the repository
  # root.
  check_eq "$(get_layer_listing "root_data_path_image" "${root_data_path_sha}")" \
    "./
./docker/
./docker/testdata/
./docker/testdata/test/
./docker/testdata/test/test"
}

# TODO(mattmoor): Needs a visibility change.
# function test_extras_with_deb() {
#   local test_data="${TEST_DATA_DIR}/extras_with_deb.tar"
#   local layer_id=02c65dd94c8fc8f31f5c5028b75d15b313e8e2854a958b4544b2b6b6de40775e

#   # The content of the layer should have no duplicate
#   local layer_listing="$(get_layer_listing "extras_with_deb" "${layer_id}" | sort)"
#   check_eq "${layer_listing}" \
# "./
# ./etc/
# ./etc/nsswitch.conf
# ./tmp/
# ./usr/
# ./usr/bin/
# ./usr/bin/java -> /path/to/bin/java
# ./usr/titi"
# }

tests=$(grep "^function test_" "${BASH_SOURCE[0]}" \
          | cut -d' ' -f 2 | cut -d'(' -f 1)

echo "Found tests: ${tests}"

for t in ${tests}; do
  echo "Testing ${t}"
  ${t}
done
