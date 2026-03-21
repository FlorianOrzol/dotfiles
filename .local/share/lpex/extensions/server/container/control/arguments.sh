#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container control
# ==============================================================================

function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    arg_value @ctid \
        --fzf \
        --description "Target Container ID" \
        --option-cmd "$(get_lxc_completion_cmd)"
        
    arg_flag @start --description "Start Container"
    arg_flag @stop --description "Stop Container"
    arg_flag @restart --description "Restart Container"
}
