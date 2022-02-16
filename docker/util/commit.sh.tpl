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

# Redirect output to a log so we can be silent on success
# intentionally don't use traps here as there might already be traps set
logfile=$(mktemp)

if ! (
    retcode=0

    if %{legacy_load_behavior}; then
        # Load the image and remember its name
        image_id=$(%{image_id_extractor_path} %{image_tar})
        $DOCKER $DOCKER_FLAGS load -i %{image_tar}

        readonly id=$($DOCKER $DOCKER_FLAGS create %{docker_run_flags} $image_id %{commands})
        if $DOCKER $DOCKER_FLAGS start -a "${id}"; then
            reset_cmd $image_id $id %{output_image}
            $DOCKER $DOCKER_FLAGS save %{output_image} -o %{output_tar}
        else
            retcode=$?
        fi
    else
        # Actually wait for the container to finish running its commands
        retcode=$($DOCKER $DOCKER_FLAGS wait $id)
        # Trigger a failure if the run had a non-zero exit status
        if [ "$retcode" != 0 ]; then
            $DOCKER $DOCKER_FLAGS logs $id && false
        fi
        reset_parent_cmd %{parent_config} $id %{output_image}
        $DOCKER $DOCKER_FLAGS save %{output_image} -o %{output_tar}
    fi

    $DOCKER $DOCKER_FLAGS rm $id
    exit "$retcode"
) > "$logfile" 2>&1; then
    cat $logfile
    exit 1
fi
