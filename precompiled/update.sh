#!/usr/bin/env bash


function compile() {
  local platform_name=$1
  local extension=$2
  bazel build \
    --platforms="@io_bazel_rules_go//go/toolchain:${platform_name}" \
    //container/go/cmd/puller:puller //container/go/cmd/loader:loader

  local platform_directory=precompiled/${platform_name}
  mkdir -p $platform_directory

  for binary_name in loader puller ;
  do
    local output="${platform_directory}/${binary_name}${extension}"
    rm -f "$output"
    cp bazel-bin/container/go/cmd/${binary_name}/${binary_name}_/${binary_name}${extension} "${output}"
  done
}

function main() {

  # Platforms we can support come from rules_go:
  #  https://github.com/bazelbuild/rules_go/blob/master/go/private/platforms.bzl

  # amd64
  compile linux_amd64
  compile darwin_amd64
  compile windows_amd64

  # arm64
  compile linux_arm64

  # s390x
  compile linux_s390x
}

main "$*"
