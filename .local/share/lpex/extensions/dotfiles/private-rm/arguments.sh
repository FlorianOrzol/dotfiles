#!/bin/bash
function arguments() {
    local tracker_file="$PATH_EXTENSION_DATA/private_tracked.txt"
    local list_cmd="cat $tracker_file 2>/dev/null || true"
    arg_value @files \
        --multi \
        --positional \
        --option-cmd "$list_cmd" \
        --description "Files/Folders to remove from the private repo"
}
