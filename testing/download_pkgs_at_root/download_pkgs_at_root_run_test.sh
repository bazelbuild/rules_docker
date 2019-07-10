#!/bin/bash

set -ex
BASEDIR=$(dirname "$0")

EXIT_CODE=0

if tar -tvf "$BASEDIR/test_download_pkgs_at_root.tar" | grep "netbase"; then
    echo "Netbase found"
else
    echo "Netbase not found"
    EXIT_CODE=1
fi

if tar -tvf "$BASEDIR/test_download_pkgs_at_root.tar" | grep "curl"; then
    echo "curl found"
else
    echo "curl not found"
    EXIT_CODE=1
fi

exit "$EXIT_CODE"
