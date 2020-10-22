#!/usr/bin/env bash

set -ex

# Move contents to a subdirectory so that output base can be set to
# /workspace/output_base
mkdir rules_docker
mv * rules_docker || true
mv .bazelrc rules_docker
