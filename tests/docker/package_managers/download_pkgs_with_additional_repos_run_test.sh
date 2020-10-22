#!/usr/bin/env bash

set -ex
BASEDIR=$(dirname "$0")

EXIT_CODE=0

if tar -tvf "$BASEDIR/test_download_pkgs_with_additional_repos.tar" | grep "bazel"; then
    echo "bazel found"
else
    echo "bazel not found"
    EXIT_CODE=1
fi

exit "$EXIT_CODE"
