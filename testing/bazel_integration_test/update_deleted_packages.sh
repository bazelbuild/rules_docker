#!/usr/bin/env bash
# For integration tests, we want to be able to glob() up the sources inside a nested package
# See explanation in .bazelrc

set -eux

DIR="$(dirname $0)/../.."
# The sed -i.bak pattern is compatible between macos and linux
sed -i.bak "/^[^#].*--deleted_packages/s#=.*#=$(\
    find examples/*/* \( -name BUILD -or -name BUILD.bazel \) | xargs -n 1 dirname | paste -sd, -\
)#" $DIR/.bazelrc && rm .bazelrc.bak
