#!/bin/bash

set -ex
BASEDIR=$(dirname "$0")

EXIT_CODE=0

if tar -tvf "$BASEDIR/test_download_pkgs_with_docker_run_flags.tar" | grep "unzip"; then
    echo "Unzip found"
else
    echo "Unzip not found"
    EXIT_CODE=1
fi

exit "$EXIT_CODE"
