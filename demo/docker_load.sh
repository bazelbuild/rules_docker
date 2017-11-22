#/bin/bash
set -x
RUN_DIR=$(dirname "$0")
docker load --input "$RUN_DIR/image.tar"
