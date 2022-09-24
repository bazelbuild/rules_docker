#!/usr/bin/env bash

set -o errexit

# Resolve the docker tool path
DOCKER="%{docker_tool_path}"
DOCKER_FLAGS="%{docker_flags}"

if [[ -z "$DOCKER" ]]; then
    echo >&2 "error: docker not found; do you need to manually configure the docker toolchain?"
    exit 1
fi

# Redirect output to a log so we can be silent on success
logfile=$(mktemp)
trap "rm $logfile" EXIT

if ! (
    # Load the image and remember its name
    image_id=$(%{image_id_extractor_path} %{image_tar})
    "$DOCKER" $DOCKER_FLAGS load -i %{image_tar}

    id=$("$DOCKER" $DOCKER_FLAGS run -d %{docker_run_flags} $image_id %{commands})

    retcode=$("$DOCKER" $DOCKER_FLAGS wait $id)

    # Print any error that occurred in the container.
    if [ $retcode != 0 ]; then
        "$DOCKER" $DOCKER_FLAGS logs $id && false
        exit $retcode
    fi

    "$DOCKER" $DOCKER_FLAGS cp $id:%{extract_file} %{output}
    "$DOCKER" $DOCKER_FLAGS rm $id
) > "$logfile" 2>&1; then
    cat "$logfile"
    exit 1
fi
