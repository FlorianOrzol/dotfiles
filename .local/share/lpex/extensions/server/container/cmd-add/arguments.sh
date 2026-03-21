#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container cmd-add
# ==============================================================================

function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    # We need to know which container this command belongs to
    arg_value @ctid \
        --fzf \
        --description "Target Container ID" \
        --option-cmd "$(get_lxc_completion_cmd)"
        
    # The short, memorable name for the command
    arg_value @alias \
        --description "Short name for the command (e.g. 'update_nginx')"
        
    # The actual long bash command to execute on the server
    arg_value @cmd \
        --description "The exact command to run in the container"
}
