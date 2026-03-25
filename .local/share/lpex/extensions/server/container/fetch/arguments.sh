#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container fetch
# ==============================================================================

function arguments() {
    
    arg_value @ctid        --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
    arg_value @remote_file --description "Absolute path to the file or directory INSIDE the container (e.g. /etc/nginx/)"
}
