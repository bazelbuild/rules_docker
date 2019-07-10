#!/bin/bash

set -ex

# Load the image and remember its name
image_id=$(python %{image_id_extractor_path} %{image_tar})
docker load -i %{image_tar}

id=$(docker run -d %{docker_run_flags} $image_id %{commands})

docker wait $id
docker cp $id:%{extract_file} %{output}
docker rm $id
