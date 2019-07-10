#!/bin/bash

set -ex

# Load utils
source %{util_script}

# Load the image and remember its name
image_id=$(python %{image_id_extractor_path} %{image_tar})
docker load -i %{image_tar}

id=$(docker run -d $image_id %{commands})
# Actually wait for the container to finish running its commands
retcode=$(docker wait $id)
# Trigger a failure if the run had a non-zero exit status
if [ $retcode != 0 ]; then
  docker logs $id && false
fi

reset_cmd $image_id $id %{output_image}
docker save %{output_image} -o %{output_tar}
docker rm $id
