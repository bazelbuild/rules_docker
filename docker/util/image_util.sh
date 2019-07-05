#!/bin/bash

reset_cmd() {
    local original_image_name=$1
    local container_id=$2
    local output_image_name=$3

    local old_cmd
    # docker inspect input cannot be piped into docker commit directly, we need to JSON format it.
    old_cmd=$(docker inspect -f "{{range .Config.Cmd}}{{.}} {{end}}" "${original_image_name}")
    fmt_cmd=$(echo "$old_cmd" | python -c "import sys,json; print json.dumps(sys.stdin.read().strip().split())")

    # If CMD wasn't set, set it to a sane default.
    if [ "$fmt_cmd" == "" ] || [ "$fmt_cmd" == "[]" ];
    then
        fmt_cmd='["/bin/sh", "-c"]'
    fi

    docker commit -c "CMD $fmt_cmd" "${container_id}" "${output_image_name}"
}
