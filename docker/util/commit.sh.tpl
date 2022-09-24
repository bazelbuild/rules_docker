#!/usr/bin/env bash

set -o errexit

# Setup tools and load utils
TO_JSON_TOOL="%{to_json_tool}"
source %{util_script}

# Resolve the docker tool path
DOCKER="%{docker_tool_path}"
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

    readonly id=$("$DOCKER" $DOCKER_FLAGS create %{docker_run_flags} $image_id %{commands})
    retcode=0
    if "$DOCKER" $DOCKER_FLAGS start -a "${id}"; then
        reset_cmd $image_id $id %{output_image}
        "$DOCKER" $DOCKER_FLAGS save %{output_image} -o %{output_tar}
    else
        retcode=$?
    fi

    "$DOCKER" $DOCKER_FLAGS rm $id
    exit "$retcode"
) > "$logfile" 2>&1; then
    cat $logfile
    exit 1
fi
