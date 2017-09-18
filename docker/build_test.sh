#!/bin/bash -e

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

# Unit tests for docker_build

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source ${DIR}/testenv.sh || { echo "testenv.sh not found!" >&2; exit 1; }

readonly PLATFORM="$(uname -s | tr 'A-Z' 'a-z')"
if [ "${PLATFORM}" = "darwin" ]; then
  readonly MAGIC_TIMESTAMP="$(date -r 0 "+%b %e  %Y")"
else
  readonly MAGIC_TIMESTAMP="$(date --date=@0 "+%F %R")"
fi

function CONTAINS() {
  local complete="${1}"
  local substring="${2}"

  echo "${complete}" | grep -Fsq -- "${substring}"
}

function EXPECT_CONTAINS() {
  local complete="${1}"
  local substring="${2}"
  local message="${3:-Expected '${substring}' not found in '${complete}'}"

  echo Checking "$1" contains "$2"
  CONTAINS "${complete}" "${substring}" || fail "$message"
}

function EXPECT_NOT_CONTAINS() {
  local complete="${1}"
  local substring="${2}"
  local message="${3:-Unexpected '${substring}' found in '${complete}'}"

  echo Checking "$1" does not contain "$2"
  (CONTAINS "${complete}" "${substring}" && fail "$message") || true
}

function no_check() {
  echo "${@}"
}

function check_property() {
  local property="${1}"
  local tarball="${2}"
  local layer="${3}"
  local expected="${4}"
  local test_data="${TEST_DATA_DIR}/${tarball}.tar"

  local metadata="$(tar xOf "${test_data}" "${layer}/json")"

  # Expect that we see the property with or without a delimiting space.
  CONTAINS "${metadata}" "\"${property}\":${expected}" || \
    EXPECT_CONTAINS "${metadata}" "\"${property}\": ${expected}"
}

function check_manifest_property() {
  local property="${1}"
  local tarball="${2}"
  local expected="${3}"
  local test_data="${TEST_DATA_DIR}/${tarball}.tar"

  local metadata="$(tar xOf "${test_data}" "manifest.json")"

  # This would be much more accurate if we had 'jq' everywhere.
  EXPECT_CONTAINS "${metadata}" "\"${property}\": ${expected}"
}

function check_no_property() {
  local property="${1}"
  local tarball="${2}"
  local layer="${3}"
  local test_data="${TEST_DATA_DIR}/${tarball}.tar"

  local metadata=$(tar xOf "${test_data}" "${layer}/json")
  EXPECT_NOT_CONTAINS "${metadata}" "\"${property}\":"
}

function check_size() {
  check_property Size "${@}"
}

function check_id() {
  check_property id "${@}"
}

function check_parent() {
  check_property parent "${@}"
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

function check_timestamp() {
  listing="$1"
  shift
  # Check that all files in the layer, if any, have the magic timestamp
  check_eq "$(echo "${listing}" | grep -Fv "${MAGIC_TIMESTAMP}" || true)" ""
}

function check_layers_aux() {
  local ancestry_check=${1}
  shift 1
  local timestamp_check=${1}
  shift 1
  local input=${1}
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
  echo Expected: ${expected_layers_sorted[@]}
  echo Actual: ${actual_layers[@]}

  check_eq "${#expected_layers[@]}" "${#actual_layers[@]}"

  local index=0
  local parent=
  while [ "${index}" -lt "${#expected_layers[@]}" ]
  do
    # Check that the nth sorted layer matches
    check_eq "${expected_layers_sorted[$index]}" "${actual_layers[$index]}"

    # Grab the ordered layer and check it.
    local layer="${expected_layers[$index]}"

    # Verbose output for testing.
    echo Checking layer: "${layer}"

    local listing="$(tar xOf "${test_data}" "${layer}/layer.tar" | tar tv)"

    "${timestamp_check}" "${listing}"

    check_id "${input}" "${layer}" "\"${layer}\""

    # Check that the layer contains its predecessor as its parent in the JSON.
    if [[ -n "${parent}" ]]; then
      "${ancestry_check}" "${input}" "${layer}" "\"${parent}\""
    fi

    index=$((index + 1))
    parent=$layer
  done
}

function check_layers() {
  local input=$1
  shift
  check_layers_aux "check_parent" "check_timestamp" "$input" "$@"
}

function get_layer_listing() {
  local input=$1
  local layer=$2
  local test_data="${TEST_DATA_DIR}/${input}.tar"
  tar xOf "${test_data}" "${layer}/layer.tar" | tar t
}

function check_listing() {
  local input=${1}
  local layer=${2}
  local expected_listing=${3}

  local actual_listing="$(get_layer_listing "${input}" "${layer}" | sort)"
  check_eq "${actual_listing}" "${expected_listing}"
}

function test_gen_image() {
  grep -Fsq "./gen.out" "$TEST_DATA_DIR/gen_image.tar" \
    || fail "'./gen.out' not found in '$TEST_DATA_DIR/gen_image.tar'"
}

function test_dummy_repository() {
  local layer="218b46f1c885aabf00cc74f896165d75a786a27792988c806246bc4f4b66a58c"
  local test_data="${TEST_DATA_DIR}/dummy_repository.tar"
  check_layers_aux "check_parent" "check_timestamp" "dummy_repository" "$layer"

  check_listing "dummy_repository" "${layer}" \
    "./
./foo"

  local repositories="$(tar xOf "${test_data}" "repositories")"
  # This would really need to use `jq` instead.
  echo "${repositories}" | \
    grep -Esq -- "\"gcr.io/dummy/[a-zA-Z_/]*/testdata\": {" \
    || fail "Cannot find image in repository gcr.io/dummy in '${repositories}'"
  EXPECT_CONTAINS "${repositories}" "\"dummy_repository\": \"$layer\""
}

function test_files_base() {
  check_layers "files_base" \
    "52a368db0b1389888ef6e9d54afa3239d52cb6a156be24eb1152df5420fc23e2"

  check_listing "files_base" \
    "52a368db0b1389888ef6e9d54afa3239d52cb6a156be24eb1152df5420fc23e2" \
    "./
./foo"
}

function test_files_with_files_base() {
  check_layers "files_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "b3dd658eaac46deca0cf79aecbad9ed6a0d410733b19f4a91e67ad0d8304fed4"

  check_listing "files_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "./
./foo"

  check_listing "files_with_files_base" \
    "b3dd658eaac46deca0cf79aecbad9ed6a0d410733b19f4a91e67ad0d8304fed4" \
    "./
./bar"
}

function test_tar_base() {
  check_layers "tar_base" \
    "6a7dd3e1930e8bd93ccd8f6dc1a01d036fa4515b20e963ba57134abcf9156837"

  check_listing "tar_base" \
    "6a7dd3e1930e8bd93ccd8f6dc1a01d036fa4515b20e963ba57134abcf9156837" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  # Check that this layer doesn't have any entrypoint data by looking
  # for *any* entrypoint.
  check_no_property "Entrypoint" "tar_base" \
    "6a7dd3e1930e8bd93ccd8f6dc1a01d036fa4515b20e963ba57134abcf9156837"
}

function test_tar_with_tar_base() {
  check_layers "tar_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "81513a235456c6466929616cc7ca3f99dc961f500e46dca4c4f1adcaec309923"

  check_listing "tar_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  check_listing "tar_with_tar_base" \
    "81513a235456c6466929616cc7ca3f99dc961f500e46dca4c4f1adcaec309923" \
    "./asdf
./usr/
./usr/bin/
./usr/bin/miraclegrow"
}

function test_directory_with_tar_base() {
  check_layers "directory_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "4bbec9b3919b97f1480489ea3fe1c79c1e209f6714947ecd6866dba43debeba5"

  check_listing "directory_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  check_listing "directory_with_tar_base" \
    "4bbec9b3919b97f1480489ea3fe1c79c1e209f6714947ecd6866dba43debeba5" \
    "./
./foo/
./foo/asdf
./foo/usr/
./foo/usr/bin/
./foo/usr/bin/miraclegrow"
}

function test_files_with_tar_base() {
  check_layers "files_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "789ceee3e7d5545f0dc4bf485f8b00ff063b142b89ed6ee4351d24569708ca38"

  check_listing "files_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  check_listing "files_with_tar_base" \
    "789ceee3e7d5545f0dc4bf485f8b00ff063b142b89ed6ee4351d24569708ca38" \
    "./
./bar"
}

function test_workdir_with_tar_base() {
  check_layers "workdir_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "f973cfb27a8ae63050977acea54b695b1622418561fa2320572f7d244321d417"

  check_listing "workdir_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  check_listing "workdir_with_tar_base" \
    "f973cfb27a8ae63050977acea54b695b1622418561fa2320572f7d244321d417" ""
}

function test_tar_with_files_base() {
  check_layers "tar_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "992188613688e67eaf640e7ec42deccd2054007efb37b6a1066c15710b800636"

  check_listing "tar_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "./
./foo"

  check_listing "tar_with_files_base" \
    "992188613688e67eaf640e7ec42deccd2054007efb37b6a1066c15710b800636" \
    "./asdf
./usr/
./usr/bin/
./usr/bin/miraclegrow"
}

function test_base_with_entrypoint() {
  check_layers "base_with_entrypoint" \
    "b31193febbdf669e6b2fd8d88c5b6ba15746c30bb7ee87e29e365f061432909d"

  check_entrypoint "base_with_entrypoint" \
    "b31193febbdf669e6b2fd8d88c5b6ba15746c30bb7ee87e29e365f061432909d" \
    '["/bar"]'

  # Check that the base layer has a port exposed.
  check_ports "base_with_entrypoint" \
    "b31193febbdf669e6b2fd8d88c5b6ba15746c30bb7ee87e29e365f061432909d" \
    '{"8080/tcp": {}}'
}

function test_dashdash_entrypoint() {
  check_layers "dashdash_entrypoint" \
    "9da930eaf19adcdc00b44036c65dceab3060f3466b4e4faafabb4256cc02f1a2"

  check_entrypoint "dashdash_entrypoint" \
    "9da930eaf19adcdc00b44036c65dceab3060f3466b4e4faafabb4256cc02f1a2" \
    '["/bar", "--"]'
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

  check_entrypoint "derivative_with_cmd" \
    "5cc64a7cf36953c4138cce9239798a02d08f8317e4997a667e3af047386be8c6" \
    '["/bar"]'

  # Check that our topmost layer excludes the shadowed arg.
  check_cmd "derivative_with_cmd" \
    "5cc64a7cf36953c4138cce9239798a02d08f8317e4997a667e3af047386be8c6" \
    '["arg1", "arg2"]'

  # Check that the topmost layer has the ports exposed by the bottom
  # layer, and itself.
  check_ports "derivative_with_cmd" \
    "5cc64a7cf36953c4138cce9239798a02d08f8317e4997a667e3af047386be8c6" \
    '{"80/tcp": {}, "8080/tcp": {}}'
}

function test_derivative_with_volume() {
  check_layers "derivative_with_volume" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "fa2a6d3ea3219d4709234411852fa9aba6c6e3ba6e8f18578e9d6afdb956a94d"

  # Check that the topmost layer has the volumes exposed by the bottom
  # layer, and itself.
  check_volumes "derivative_with_volume" \
    "fa2a6d3ea3219d4709234411852fa9aba6c6e3ba6e8f18578e9d6afdb956a94d" \
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
    "88c91434164941eca46c750d29c9f75520279030fe0f4406384578e99c30995b" \
    '["bar=blah blah blah", "foo=/asdf"]'

  # We should have a tag in our manifest, otherwise it will be untagged
  # when loaded in newer clients.
  check_manifest_property "RepoTags" "with_env" \
    "[\"bazel/${TEST_DATA_TARGET_BASE}:with_env\"]"
}

function test_with_double_env() {
  check_layers "with_double_env" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "2a3516c812912a587c4bd0b0d9ce4529733d2e854d91ffa712179df91200cd99"

  # Check both the aggregation and the expansion of embedded variables.
  check_env "with_double_env" \
    "2a3516c812912a587c4bd0b0d9ce4529733d2e854d91ffa712179df91200cd99" \
    '["bar=blah blah blah", "baz=/asdf blah blah blah", "foo=/asdf"]'
}

function test_with_label() {
  check_layers "with_label" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "9fa7995a3e26a09402880cf5b30742cc050a2f8c52755dfda8eec7d913818518"

  check_label "with_label" \
    "9fa7995a3e26a09402880cf5b30742cc050a2f8c52755dfda8eec7d913818518" \
    '{"com.example.bar": "{\"name\": \"blah\"}", "com.example.baz": "qux", "com.example.foo": "{\"name\": \"blah\"}"}'
}

function test_with_double_label() {
  check_layers "with_double_label" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "f1e16a3a34cc4734286114b23cb2600d5bf1e54cb2d51ba30366c1acb713de6f"

  check_label "with_double_label" \
    "f1e16a3a34cc4734286114b23cb2600d5bf1e54cb2d51ba30366c1acb713de6f" \
    '{"com.example.bar": "{\"name\": \"blah\"}", "com.example.baz": "qux", "com.example.foo": "{\"name\": \"blah\"}", "com.example.qux": "{\"name\": \"blah-blah\"}"}'
}

function test_with_user() {
  check_layers "with_user" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "7db1ae56da4e38e4af9da1c0e6886d6584e25beb6bcda6d715c3b2134123ede8"

  check_user "with_user" \
    "7db1ae56da4e38e4af9da1c0e6886d6584e25beb6bcda6d715c3b2134123ede8" \
    "\"nobody\""
}

function test_data_path() {
  local no_data_path_sha="171db1e2bb7a5728972e742baa9161dd3972e6ec9fc3cf12cc274b22885c3f22"
  local data_path_sha="78d0d05dd43edd60e9e5257377fedd1694ddeecf31a5e8098649cf2b4ae2120a"
  local absolute_data_path_sha="973ef07a5fd59eeb307bf6e9e22ae8ed3ac3a0c4ceeef765d7fbd4bc9f7c754e"
  local root_data_path_sha="973ef07a5fd59eeb307bf6e9e22ae8ed3ac3a0c4ceeef765d7fbd4bc9f7c754e"

  check_layers_aux "check_parent" "check_timestamp" "no_data_path_image" "${no_data_path_sha}"
  check_layers_aux "check_parent" "check_timestamp" "data_path_image" "${data_path_sha}"
  check_layers_aux "check_parent" "check_timestamp" "absolute_data_path_image" "${absolute_data_path_sha}"
  check_layers_aux "check_parent" "check_timestamp" "root_data_path_image" "${root_data_path_sha}"

  # Without data_path = "." the file will be inserted as `./test`
  # (since it is the path in the package) and with data_path = "."
  # the file will be inserted relatively to the testdata package
  # (so `./test/test`).
  check_listing "no_data_path_image" "${no_data_path_sha}" \
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
  check_listing "absolute_data_path_image" "${absolute_data_path_sha}" \
    './
./docker/
./docker/testdata/
./docker/testdata/test/
./docker/testdata/test/test'

  # With data_path = "/", we expect the entire path from the repository
  # root.
  check_listing "root_data_path_image" "${root_data_path_sha}" \
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

function test_bundle() {
  # The three images:
  check_layers "with_double_env" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "2a3516c812912a587c4bd0b0d9ce4529733d2e854d91ffa712179df91200cd99"
  check_layers "base_with_entrypoint" \
    "b31193febbdf669e6b2fd8d88c5b6ba15746c30bb7ee87e29e365f061432909d"
  check_layers "link_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "2be8398e365aa4a785f83f0c137452fc151b7c42252cd636746cd4cbc925f395"

  # Check that we have these layers, but ignore the parent check, since
  # this is a tree not a list.
  check_layers_aux "no_check" "no_check" "bundle_test" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "2a3516c812912a587c4bd0b0d9ce4529733d2e854d91ffa712179df91200cd99" \
    "b31193febbdf669e6b2fd8d88c5b6ba15746c30bb7ee87e29e365f061432909d" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "2be8398e365aa4a785f83f0c137452fc151b7c42252cd636746cd4cbc925f395"

  # Our bundle should have the following aliases.
  check_manifest_property "RepoTags" "bundle_test" \
    "[\"docker.io/ubuntu:latest\"]"

  check_manifest_property "RepoTags" "bundle_test" \
    "[\"us.gcr.io/google-appengine/base:fresh\"]"

  check_manifest_property "RepoTags" "bundle_test" \
    "[\"gcr.io/google-containers/pause:2.0\"]"
}

function test_stamped_bundle() {
  check_manifest_property "RepoTags" "stamped_bundle_test" \
    "[\"example.com/aaaaa$USER:stamped\"]"
}

function test_stamped_bundle() {
  # The path to the script.
  local test_data="${TEST_DATA_DIR}/stamped_bundle_test"

  # The script contents.
  local script="$(cat ${test_data})"

  EXPECT_CONTAINS "${script}" "read_variables"
  EXPECT_CONTAINS "${script}" '${BUILD_USER}'
}

function test_pause_based() {
  # Check that when we add a single layer on top of a checked in tarball, that
  # all of the layers from the original tarball are included.  We omit the
  # ancestry check because its expectations of layer ordering don't match the
  # order produced vai tarball imports.  We omit the timestamp check because
  # the checked in tarball doesn't have scrubbed timestamps.
  check_layers_aux "no_check" "no_check" "pause_based" \
    "8202aa2d96920a1dd8b1e807c0765ef399c28c19e0c5751439d9c04bcfbd0bf1" \
    "bbe05a2cfcab717f7b19a7a62c592d677dd479ad61059b8b3e8af45c71da8dae" \
    "e8f49a9596be38e6266cdeac79d07f17a1845b433e3ded5476e48c20347f763b"
}

function test_build_with_tag() {
  # We should have a tag in our manifest containing the name
  # specified via the tag kwarg.
  check_manifest_property "RepoTags" "build_with_tag" \
    "[\"gcr.io/build/with:tag\"]"
}

function test_build_with_passwd() {
  # We should have a tag in our manifest containing the name
  # specified via the tag kwarg.

  local layer="999fb74aff8830ac7c4c3658d30bef6913f2529ec9a0bc2531ce7b6deb1988b9"
  check_layers "with_passwd" "${layer}"

  check_listing "with_passwd" "${layer}" \
    './
./etc/
./etc/passwd'

  local test_data="${TEST_DATA_DIR}/with_passwd.tar"
  echo $test_data
  passwd_contents=$(tar xOf "${test_data}" "${layer}/layer.tar" | tar xO "./etc/passwd")
  check_eq ${passwd_contents} "foobar:x:1234:2345:myusernameinfo:/myhomedir:/myshell"
}

function get_layers() {
  local tarball="${1}"
  local test_data="${TEST_DATA_DIR}/${tarball}.tar"

  python <<EOF
import json
import tarfile

with tarfile.open("${test_data}", "r") as tar:
  manifests = json.loads(tar.extractfile("manifest.json").read())
  assert len(manifests) == 1
  for m in manifests:
    for l in m["Layers"]:
      print(l)
EOF
}

function test_py_image() {
  # Don't check the full layer set because the base will vary,
  # but check the files in our top two layers.
  local layers=($(get_layers "py_image"))
  local length="${#layers[@]}"
  local lib_layer=$(dirname "${layers[$((length-2))]}")
  local bin_layer=$(dirname "${layers[$((length-1))]}")

  # TODO(mattmoor): The path normalization for symlinks should match
  # files to avoid this redundancy.
  check_listing "py_image" "${lib_layer}" \
    './
./app/
./app/docker/
./app/docker/__init__.py
./app/docker/testdata/
./app/docker/testdata/__init__.py
./app/docker/testdata/py_image_library.py'

  check_listing "py_image" "${bin_layer}" \
    './
./app/
./app/docker/
./app/docker/testdata/
./app/docker/testdata/py_image.binary.runfiles/
./app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/
./app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/
./app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/
./app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/py_image.binary
./app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/py_image.py
/app/
/app/docker/
/app/docker/testdata/
/app/docker/testdata/py_image.binary
/app/docker/testdata/py_image.binary.runfiles/
/app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/
/app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/
/app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/
/app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/docker/
/app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/docker/__init__.py
/app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/docker/testdata/
/app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/docker/testdata/__init__.py
/app/docker/testdata/py_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/docker/testdata/py_image_library.py'
}

function test_cc_image() {
  # Don't check the full layer set because the base will vary,
  # but check the files in our top two layers.
  local layers=($(get_layers "cc_image"))
  local length="${#layers[@]}"
  local lib_layer=$(dirname "${layers[$((length-2))]}")
  local bin_layer=$(dirname "${layers[$((length-1))]}")

  # The linker pulls the object files into the final binary,
  # so in C++ dependencies don't help when specified via `layers`.
  check_listing "cc_image" "${lib_layer}" ''

  check_listing "cc_image" "${bin_layer}" \
    './
./app/
./app/docker/
./app/docker/testdata/
./app/docker/testdata/cc_image.binary.runfiles/
./app/docker/testdata/cc_image.binary.runfiles/io_bazel_rules_docker/
./app/docker/testdata/cc_image.binary.runfiles/io_bazel_rules_docker/docker/
./app/docker/testdata/cc_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/
./app/docker/testdata/cc_image.binary.runfiles/io_bazel_rules_docker/docker/testdata/cc_image.binary
/app/
/app/docker/
/app/docker/testdata/
/app/docker/testdata/cc_image.binary'
}

function test_java_image() {
  # Don't check the full layer set because the base will vary,
  # but check the files in our top two layers.
  local layers=($(get_layers "java_image"))
  local length="${#layers[@]}"
  local lib_layer=$(dirname "${layers[$((length-2))]}")
  local bin_layer=$(dirname "${layers[$((length-1))]}")

  # The path here for Guava is *really* weird, which is a function
  # of the bug linked from build.bzl's magic_path function.
  check_listing "java_image" "${lib_layer}" \
'./
./app/
./app/docker/
./app/docker/com_google_guava_guava/
./app/docker/com_google_guava_guava/jar/
./app/docker/com_google_guava_guava/jar/guava-18.0.jar
./app/docker/testdata/
./app/docker/testdata/libjava_image_library.jar'

  check_listing "java_image" "${bin_layer}" \
'./
./app/
./app/docker/
./app/docker/testdata/
./app/docker/testdata/java_image.binary
./app/docker/testdata/java_image.binary.jar
./app/docker/testdata/java_image.classpath'
}

function test_war_image() {
  # Don't check the full layer set because the base will vary,
  # but check the files in our top two layers.
  local layers=($(get_layers "war_image"))
  local length="${#layers[@]}"
  local lib_layer=$(dirname "${layers[$((length-2))]}")
  local bin_layer=$(dirname "${layers[$((length-1))]}")

  check_listing "war_image" "${lib_layer}" \
'./
./jetty/
./jetty/webapps/
./jetty/webapps/ROOT/
./jetty/webapps/ROOT/WEB-INF/
./jetty/webapps/ROOT/WEB-INF/lib/
./jetty/webapps/ROOT/WEB-INF/lib/javax.servlet-api-3.0.1.jar'

  check_listing "war_image" "${bin_layer}" \
'./
./jetty/
./jetty/webapps/
./jetty/webapps/ROOT/
./jetty/webapps/ROOT/WEB-INF/
./jetty/webapps/ROOT/WEB-INF/lib/
./jetty/webapps/ROOT/WEB-INF/lib/libwar_image.library.jar'
}

tests=$(grep "^function test_" "${BASH_SOURCE[0]}" \
          | cut -d' ' -f 2 | cut -d'(' -f 1)

echo "Found tests: ${tests}"

for t in ${tests}; do
  echo "Testing ${t}"
  ${t}
done
