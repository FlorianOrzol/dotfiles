#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container control
# ==============================================================================

function arguments() {
    
    arg_value @ctid --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
    
    # State flags (Mutually exclusive by nature, handled logically in main)
    arg_flag @start   --description "Power on the container"
    arg_flag @stop    --description "Gracefully power off the container"
    arg_flag @restart --description "Reboot the container"
}
