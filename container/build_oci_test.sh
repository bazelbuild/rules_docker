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
  check_property Labels "${input}" "${@}"
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
  local layer="218b46f1c885aabf00cc74f896165d75a786a27792988c806246bc4f4b66a58c"
  local test_data="${TEST_DATA_DIR}/dummy_repository.tar"
  check_layers_aux "dummy_repository" "$layer"
}

function test_files_base() {
  check_layers "files_base" \
    "52a368db0b1389888ef6e9d54afa3239d52cb6a156be24eb1152df5420fc23e2"
}

function test_files_with_files_base() {
  check_layers "files_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "b3dd658eaac46deca0cf79aecbad9ed6a0d410733b19f4a91e67ad0d8304fed4"
}

function test_tar_base() {
  check_layers "tar_base" \
    "6a7dd3e1930e8bd93ccd8f6dc1a01d036fa4515b20e963ba57134abcf9156837"

  # Check that this layer doesn't have any entrypoint data by looking
  # for *any* entrypoint.
  check_no_property "Entrypoint" "tar_base" \
    "9fec194fd32c03350d6a6e60ee8ed7862471e8817aaa310306d9be6242b05d20"
}

function test_tar_with_tar_base() {
  check_layers "tar_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "81513a235456c6466929616cc7ca3f99dc961f500e46dca4c4f1adcaec309923"
}

function test_directory_with_tar_base() {
  check_layers "directory_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "4bbec9b3919b97f1480489ea3fe1c79c1e209f6714947ecd6866dba43debeba5"
}

function test_files_with_tar_base() {
  check_layers "files_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "789ceee3e7d5545f0dc4bf485f8b00ff063b142b89ed6ee4351d24569708ca38"
}

function test_workdir_with_tar_base() {
  check_layers "workdir_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "f973cfb27a8ae63050977acea54b695b1622418561fa2320572f7d244321d417"
}

function test_tar_with_files_base() {
  check_layers "tar_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "992188613688e67eaf640e7ec42deccd2054007efb37b6a1066c15710b800636"
}

function test_base_with_entrypoint() {
  check_layers "base_with_entrypoint" \
    "b31193febbdf669e6b2fd8d88c5b6ba15746c30bb7ee87e29e365f061432909d"

  check_entrypoint "base_with_entrypoint" \
    "dc7727161acbf507d282f96078bcbabf2cf64d65de4a8fb64ebcaa3a47c9e589" \
    '["/bar"]'

  # Check that the base layer has a port exposed.
  check_ports "base_with_entrypoint" \
    "dc7727161acbf507d282f96078bcbabf2cf64d65de4a8fb64ebcaa3a47c9e589" \
    '{"8080/tcp": {}}'
}

function test_derivative_with_shadowed_cmd() {
  check_layers "derivative_with_shadowed_cmd" \
    "924348d4f092ab4b3a17e14c68d8e42e2c6564bde6d5d72f2e8fb66ac1bfe20a" \
    "fc285db972e45cc1f74735e5ddacb51b5ac7d9ab0a712a721da6075392b7d766"
}

function test_derivative_with_cmd() {
  check_layers "derivative_with_cmd" \
    "924348d4f092ab4b3a17e14c68d8e42e2c6564bde6d5d72f2e8fb66ac1bfe20a" \
    "3ecdff6ae8d5240aa21295c0b425c2d1adb08e10bd10ce77f27d5896a72960e3" \
    "5cc64a7cf36953c4138cce9239798a02d08f8317e4997a667e3af047386be8c6"

  check_images "derivative_with_cmd" \
    "efb79a54a41dff95946e91cce83f7c818941e69443036c689668e0d0b03b6c13"

  check_entrypoint "derivative_with_cmd" \
    "efb79a54a41dff95946e91cce83f7c818941e69443036c689668e0d0b03b6c13" \
    '["/bar"]'
}

function test_derivative_with_volume() {
  check_layers "derivative_with_volume" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "fa2a6d3ea3219d4709234411852fa9aba6c6e3ba6e8f18578e9d6afdb956a94d"

  check_images "derivative_with_volume" \
    "742571cc03d8fb271262b670b1e740905ddc99bc60cd63dbb2b9d34be8b7af7d"

  # Check that the topmost layer has the ports exposed by the bottom
  # layer, and itself.
  check_volumes "derivative_with_volume" \
    "742571cc03d8fb271262b670b1e740905ddc99bc60cd63dbb2b9d34be8b7af7d" \
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
    "88c91434164941eca46c750d29c9f75520279030fe0f4406384578e99c30995b"

  check_env "with_env" \
    "cd87cf17d71867fc418ddd9740ded65d65fb659fef9df439d8bc270058ab6591" \
    '["bar=blah blah blah", "foo=/asdf"]'
}

function test_with_double_env() {
  check_layers "with_double_env" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "2a3516c812912a587c4bd0b0d9ce4529733d2e854d91ffa712179df91200cd99"

  # Check both the aggregation and the expansion of embedded variables.
  check_env "with_double_env" \
    "6267bccc74f5060236bc7ff4ab11b503d51158c96c498e269104ed04bcfe99ee" \
    '["bar=blah blah blah", "baz=/asdf blah blah blah", "foo=/asdf"]'
}

function test_with_label() {
  check_layers "with_label" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "9fa7995a3e26a09402880cf5b30742cc050a2f8c52755dfda8eec7d913818518" \

  check_label "with_label" \
    "f983d9c4380bb2283497981d98b24c4cc93ca522646ccc8323e60517ab2378f6" \
    '{"com.example.bar": "{\"name\": \"blah\"}", "com.example.baz": "qux", "com.example.foo": "{\"name\": \"blah\"}"}'
}

function test_with_double_label() {
  check_layers "with_double_label" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "f1e16a3a34cc4734286114b23cb2600d5bf1e54cb2d51ba30366c1acb713de6f"

  check_label "with_double_label" \
    "b7cf5f02c7a4b86fdc9b94c5cc667c3fb2b7f2482ce8dc26f51853f24deaedcf" \
    '{"com.example.bar": "{\"name\": \"blah\"}", "com.example.baz": "qux", "com.example.foo": "{\"name\": \"blah\"}", "com.example.qux": "{\"name\": \"blah-blah\"}"}'
}

function test_with_user() {
  check_layers "with_user" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "7db1ae56da4e38e4af9da1c0e6886d6584e25beb6bcda6d715c3b2134123ede8"

  check_user "with_user" \
    "cfa26e5de2afd53591c12efe0aa7aff0c7b1f2fd6f9d774fa26bd3ca734a4f99" \
    "\"nobody\""
}

function get_layer_listing() {
  local input=$1
  local layer=$2
  local test_data="${TEST_DATA_DIR}/${input}.tar"
  tar xOf "${test_data}" "${layer}/layer.tar" | tar t
}

function test_data_path() {
  local no_data_path_sha="171db1e2bb7a5728972e742baa9161dd3972e6ec9fc3cf12cc274b22885c3f22"
  local data_path_sha="78d0d05dd43edd60e9e5257377fedd1694ddeecf31a5e8098649cf2b4ae2120a"
  local absolute_data_path_sha="21fc5e122cef459089086b61663dd1aac77de7f741e7285c1b4b312215100d7e"
  local root_data_path_sha="21fc5e122cef459089086b61663dd1aac77de7f741e7285c1b4b312215100d7e"

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
  # //testdata and data_path is set to
  # "/tools/build_defs", we should have `docker` as the top-level
  # directory.
  check_eq "$(get_layer_listing "absolute_data_path_image" "${absolute_data_path_sha}")" \
    './
./testdata/
./testdata/test/
./testdata/test/test'

  # With data_path = "/", we expect the entire path from the repository
  # root.
  check_eq "$(get_layer_listing "root_data_path_image" "${root_data_path_sha}")" \
    "./
./testdata/
./testdata/test/
./testdata/test/test"
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
