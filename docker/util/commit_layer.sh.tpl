#!/usr/bin/env bash

set -o errexit

# Load utils
source %{util_script}

# Resolve the docker tool path
DOCKER="$(readlink -nf %{docker_tool_path})"
DOCKER_FLAGS="%{docker_flags}"

if [[ -z "$DOCKER" ]]; then
    echo >&2 "error: docker not found; do you need to manually configure the docker toolchain?"
    exit 1
fi

logfile=$(output_logfile)

if ! (
    # Load the image and remember its name
    image_id=$(%{image_id_extractor_path} %{image_tar})
    "$DOCKER" $DOCKER_FLAGS load -i %{image_tar}

    readonly id=$("$DOCKER" $DOCKER_FLAGS create %{docker_run_flags} --env-file %{env_file_path} $image_id %{commands})
    retcode=0
    if "$DOCKER" $DOCKER_FLAGS start -a "${id}"; then
        OUTPUT_IMAGE_TAR="%{output_layer_tar}.image.tar"
        reset_cmd $image_id $id %{output_image}
        "$DOCKER" $DOCKER_FLAGS save %{output_image} -o $OUTPUT_IMAGE_TAR

        # Extract the last layer from the image - this will be the layer generated by "$DOCKER" commit
        %{image_last_layer_extractor_path} $OUTPUT_IMAGE_TAR %{output_layer_tar} %{output_diff_id}

        # Delete the intermediate tar
        rm $OUTPUT_IMAGE_TAR
    else
        retcode=$?
    fi

    # Delete the container and the intermediate image
    "$DOCKER" $DOCKER_FLAGS rm $id
    "$DOCKER" $DOCKER_FLAGS rmi %{output_image}

    exit "$retcode"
) > "$logfile" 2>&1; then
    cat "$logfile"
    exit 1
fi
