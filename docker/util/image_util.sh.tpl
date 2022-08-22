#!/usr/bin/env bash

reset_cmd() {
    local original_image_name=$1
    local container_id=$2
    local output_image_name=$3

    # Resolve the docker tool path
    DOCKER="%{docker_tool_path}"
    DOCKER_FLAGS="%{docker_flags}"
    local old_cmd
    # docker inspect input cannot be piped into docker commit directly, we need to JSON format it.
    old_cmd=$("$DOCKER" $DOCKER_FLAGS inspect -f "{{range .Config.Cmd}}{{.}} {{end}}" "${original_image_name}")
    fmt_cmd=$(echo "$old_cmd" | ${TO_JSON_TOOL})
    # If CMD wasn't set, set it to a sane default.
    if [ "$fmt_cmd" == "" ] || [ "$fmt_cmd" == "[]" ];
    then
        fmt_cmd='["/bin/sh", "-c"]'
    fi

    "$DOCKER" $DOCKER_FLAGS commit -c "CMD $fmt_cmd" "${container_id}" "${output_image_name}"
}

function output_logfile {
    readonly filename=$(mktemp)

    function cleanup {
        test -f "$filename"
        cat "$filename"
        rm "$filename"
    }
    trap cleanup EXIT

    echo $filename
}
