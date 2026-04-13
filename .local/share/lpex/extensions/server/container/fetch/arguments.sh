#!/bin/bash
# ==============================================================================
# @meta_module      : server container fetch
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server container fetch'.
#
# @arg_values       : --ctid        | Target container ID (fzf-selectable)
# @arg_values       : --remote-file | Absolute path inside the container to fetch
# ==============================================================================
function arguments() {
    
    arg_value @ctid        --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
    arg_value @remote_file --description "Absolute path to the file or directory INSIDE the container (e.g. /etc/nginx/)"
}
