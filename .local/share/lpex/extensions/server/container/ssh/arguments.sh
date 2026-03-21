#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container ssh
# ==============================================================================

function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    arg_value @ctid \
        --fzf \
        --description "Target Container ID to attach to" \
        --option-cmd "$(get_lxc_completion_cmd)"
}
