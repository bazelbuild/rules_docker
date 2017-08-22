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
  local layer="7771c123a312b2d11b841ac88b8d349fd472288e019d90e0298177c237e8548d"
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
    "ef2df17c7d29bc9716c86a40311a1c026d7f328374e69e003e7af64f6e148a1b"

  check_listing "files_base" \
    "ef2df17c7d29bc9716c86a40311a1c026d7f328374e69e003e7af64f6e148a1b" \
    "./
./foo"
}

function test_files_with_files_base() {
  check_layers "files_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "7d3922332e0b0720caa78a5fac5df60f31ce63a8f7bcbf1369cf50cf0f2eec89"

  check_listing "files_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "./
./foo"

  check_listing "files_with_files_base" \
    "7d3922332e0b0720caa78a5fac5df60f31ce63a8f7bcbf1369cf50cf0f2eec89" \
    "./
./bar"
}

function test_tar_base() {
  check_layers "tar_base" \
    "823a94eba6bd535a1badc72f7258e8f4d96d6ff636e3c4c409128a6de1e8df39"

  check_listing "tar_base" \
    "823a94eba6bd535a1badc72f7258e8f4d96d6ff636e3c4c409128a6de1e8df39" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  # Check that this layer doesn't have any entrypoint data by looking
  # for *any* entrypoint.
  check_no_property "Entrypoint" "tar_base" \
    "823a94eba6bd535a1badc72f7258e8f4d96d6ff636e3c4c409128a6de1e8df39"
}

function test_tar_with_tar_base() {
  check_layers "tar_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "01d70f1c84473e80c71fb1392aa605c834bf27f23ac78d6f8292348770ba9051"

  check_listing "tar_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  check_listing "tar_with_tar_base" \
    "01d70f1c84473e80c71fb1392aa605c834bf27f23ac78d6f8292348770ba9051" \
    "./asdf
./usr/
./usr/bin/
./usr/bin/miraclegrow"
}

function test_directory_with_tar_base() {
  check_layers "directory_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "9888a583af14e1d51b2bc18003dab010a3781aa0d85603fa1b952f693a76ffb1"

  check_listing "directory_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  check_listing "directory_with_tar_base" \
    "9888a583af14e1d51b2bc18003dab010a3781aa0d85603fa1b952f693a76ffb1" \
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
    "b0b24d40d4d3492d6a8115c595c9ae225491ba35ea9f37121b440733275d1af1"

  check_listing "files_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  check_listing "files_with_tar_base" \
    "b0b24d40d4d3492d6a8115c595c9ae225491ba35ea9f37121b440733275d1af1" \
    "./
./bar"
}

function test_workdir_with_tar_base() {
  check_layers "workdir_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "5915f95557288f70c1b852a407287431b77598ef4212a177d9aa7fd895c1d532"

  check_listing "workdir_with_tar_base" \
    "b87a71a87c61a17440123d30023adea0d277bdb9926a11b0b016b61a33098908" \
    "./usr/
./usr/bin/
./usr/bin/unremarkabledeath"

  check_listing "workdir_with_tar_base" \
    "5915f95557288f70c1b852a407287431b77598ef4212a177d9aa7fd895c1d532" ""
}

function test_tar_with_files_base() {
  check_layers "tar_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "e9dcbb6979d1c16c832f3a2879788a123da3b81c98a98ef2ba7f44e73da1edc8"

  check_listing "tar_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "./
./foo"

  check_listing "tar_with_files_base" \
    "e9dcbb6979d1c16c832f3a2879788a123da3b81c98a98ef2ba7f44e73da1edc8" \
    "./asdf
./usr/
./usr/bin/
./usr/bin/miraclegrow"
}

function test_base_with_entrypoint() {
  check_layers "base_with_entrypoint" \
    "2296fe5c1a9cf075fa2dea939d51ee263dd8c9b8f91030e07f56bc27bffa1ab5"

  check_entrypoint "base_with_entrypoint" \
    "2296fe5c1a9cf075fa2dea939d51ee263dd8c9b8f91030e07f56bc27bffa1ab5" \
    '["/bar"]'

  # Check that the base layer has a port exposed.
  check_ports "base_with_entrypoint" \
    "2296fe5c1a9cf075fa2dea939d51ee263dd8c9b8f91030e07f56bc27bffa1ab5" \
    '{"8080/tcp": {}}'
}

function test_dashdash_entrypoint() {
  check_layers "dashdash_entrypoint" \
    "cd4e18bfecd3235612666036ebf4e57e0904b64d243f578b857b4ad50273669c"

  check_entrypoint "dashdash_entrypoint" \
    "cd4e18bfecd3235612666036ebf4e57e0904b64d243f578b857b4ad50273669c" \
    '["/bar", "--"]'
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

  check_entrypoint "derivative_with_cmd" \
    "354cd9c43dd83f0aecf8d1091b61b7e7ea0c31b2079c8b7c9b2c14f7d989c4a0" \
    '["/bar"]'

  # Check that our topmost layer excludes the shadowed arg.
  check_cmd "derivative_with_cmd" \
    "354cd9c43dd83f0aecf8d1091b61b7e7ea0c31b2079c8b7c9b2c14f7d989c4a0" \
    '["arg1", "arg2"]'

  # Check that the topmost layer has the ports exposed by the bottom
  # layer, and itself.
  check_ports "derivative_with_cmd" \
    "354cd9c43dd83f0aecf8d1091b61b7e7ea0c31b2079c8b7c9b2c14f7d989c4a0" \
    '{"80/tcp": {}, "8080/tcp": {}}'
}

function test_derivative_with_volume() {
  check_layers "derivative_with_volume" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "f69c3d81f60ad3efc8ee66f7c6241bf2450bb7fb8b14d12164b5f57b64b3086b"

  # Check that the topmost layer has the volumes exposed by the bottom
  # layer, and itself.
  check_volumes "derivative_with_volume" \
    "f69c3d81f60ad3efc8ee66f7c6241bf2450bb7fb8b14d12164b5f57b64b3086b" \
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
    "958057ce6cd518030ed84548a16d72f1c3d168c71222368e0bbfd3e5b0dc3725" \
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
    "a1eafb9b3f015fc28237bf9e10f9a6103dd9d29368f081952207fddcd1045833"

  # Check both the aggregation and the expansion of embedded variables.
  check_env "with_double_env" \
    "a1eafb9b3f015fc28237bf9e10f9a6103dd9d29368f081952207fddcd1045833" \
    '["bar=blah blah blah", "baz=/asdf blah blah blah", "foo=/asdf"]'
}

function test_with_label() {
  check_layers "with_label" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "57438bbe887e61de6b535eda83047c45ee1f98e2bf50071358e617067ccb04aa"

  check_label "with_label" \
    "57438bbe887e61de6b535eda83047c45ee1f98e2bf50071358e617067ccb04aa" \
    '["com.example.bar={\"name\": \"blah\"}", "com.example.baz=qux", "com.example.foo={\"name\": \"blah\"}"]'
}

function test_with_double_label() {
  check_layers "with_double_label" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "b14fe258f95cd176eef757a7343508f028cf568e0feb9fea677469742700534e"

  check_label "with_double_label" \
    "b14fe258f95cd176eef757a7343508f028cf568e0feb9fea677469742700534e" \
    '["com.example.bar={\"name\": \"blah\"}", "com.example.baz=qux", "com.example.foo={\"name\": \"blah\"}", "com.example.qux={\"name\": \"blah-blah\"}"]'
}

function test_with_user() {
  check_layers "with_user" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "5f8e5f6593a746cb509459aee90b2ac9c64031db513e8a013ef6236c821e72a4"

  check_user "with_user" \
    "5f8e5f6593a746cb509459aee90b2ac9c64031db513e8a013ef6236c821e72a4" \
    "\"nobody\""
}

function test_data_path() {
  local no_data_path_sha="de3853f68a7edad8a8adb83363652d0927d6a69c6ed790e85bf0048892134bbc"
  local data_path_sha="0ea8ce6cf08d60758c509295987232a41a9b07676533c6aae8d7608c85fb2b82"
  local absolute_data_path_sha="800edeae00c369c8caadf06a816014629f6144c857ee33facfb6ab82705d83ef"
  local root_data_path_sha="800edeae00c369c8caadf06a816014629f6144c857ee33facfb6ab82705d83ef"

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
    "a1eafb9b3f015fc28237bf9e10f9a6103dd9d29368f081952207fddcd1045833"
  check_layers "base_with_entrypoint" \
    "2296fe5c1a9cf075fa2dea939d51ee263dd8c9b8f91030e07f56bc27bffa1ab5"
  check_layers "link_with_files_base" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "6b16a7204dc5667ecf0456c51c30ec306138b1bde6e9bd165ad8d4e8263fff86"

  # Check that we have these layers, but ignore the parent check, since
  # this is a tree not a list.
  check_layers_aux "no_check" "no_check" "bundle_test" \
    "5e01cffa06e7ab7f23f1e46fe2e567084477d03e35692f20b6ad0ea2e51fe24e" \
    "0e14197f4601f043f0e3e6b209c5962ac96da809d25d4cf0e5c38be52151a515" \
    "a1eafb9b3f015fc28237bf9e10f9a6103dd9d29368f081952207fddcd1045833" \
    "2296fe5c1a9cf075fa2dea939d51ee263dd8c9b8f91030e07f56bc27bffa1ab5" \
    "669910cb103f8c2f1ee940975f73a1e23673046d5428718358083cbb3341b132" \
    "6b16a7204dc5667ecf0456c51c30ec306138b1bde6e9bd165ad8d4e8263fff86"

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
    "c887023a27797b968b7c28f44701026e81ff2b517b330f7e3f46db8af0862b77" \
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

  local layer="7ec6c579c3d2c33a3dec8088b4a2bffdf1e86d1c0da1e98858588b9946610e07"
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
