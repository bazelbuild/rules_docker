#!/usr/bin/env bash
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

function fail() {
  echo "FAILURE: $1"
  exit 1
}

function CONTAINS() {
  local complete="${1}"
  local substring="${2}"

  echo "${complete}" | grep -Fsq -- "${substring}"
}

function COUNT() {
  local complete="${1}"
  local substring="${2}"

  echo "${complete}" | grep -Fso -- "${substring}" | wc -l
}

function EXPECT_CONTAINS() {
  local complete="${1}"
  local substring="${2}"
  local message="${3:-Expected '${substring}' not found in '${complete}'}"

  echo Checking "$1" contains "$2"
  CONTAINS "${complete}" "${substring}" || fail "$message"
}

function EXPECT_CONTAINS_ONCE() {
  local complete="${1}"
  local substring="${2}"
  local count=$(COUNT "${complete}" "${substring}")

  echo Checking "$1" contains "$2" exactly once
  if [[ count -ne "1" ]]; then
    fail "${3:-Expected '${substring}' found ${count} in '${complete}'}"
  fi
}

function EXPECT_NOT_CONTAINS() {
  local complete="${1}"
  local substring="${2}"
  local message="${3:-Expected '${substring}' found in '${complete}'}"

  echo Checking "$1" does not contain "$2"
  ! (CONTAINS "${complete}" "${substring}") || fail "$message"
}

function clear_docker() {
  # Get the IDs of images, filtering only the ones with "bazel/*" as registry
  # and filtering the local registry image "registry:2" which is
  # used in a few of the tests. This avoids having to pull the registry image
  # multiple times in the end to end tests.
  images=$(docker images "bazel/*" -a --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep -v "registry:2" | cut -d' ' -f1)
  if [ ! -z "$images" ]; then
    docker rmi -f $images || builtin true
  fi
}
