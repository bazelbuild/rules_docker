#!/usr/bin/env bash

BASEDIR=$(dirname "$0")

# Expose content of config file, just for logging
cat ${BASEDIR}/${2}.0.config; echo

# Check if architecture passed in arg ${1} matches the config file
if grep -q \"architecture\":\"${1}\" ${BASEDIR}/${2}.0.config; then
       echo "Architecture ${1} in arg matches the config file"
else
       echo "Architecture ${1} in arg does not match the config file"
       exit 1
fi
