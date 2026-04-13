#!/bin/bash
# ==============================================================================
# @meta_module      : server container control
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server container control'.
#
# @arg_values       : --ctid    | Target container ID (fzf-selectable)
# @arg_flags        : --start   | Power on the container
# @arg_flags        : --stop    | Gracefully stop the container
# @arg_flags        : --restart | Reboot the container
# ==============================================================================
function arguments() {
    
    arg_value @ctid --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
    
    # State flags (Mutually exclusive by nature, handled logically in main)
    arg_flag @start   --description "Power on the container"
    arg_flag @stop    --description "Gracefully power off the container"
    arg_flag @restart --description "Reboot the container"
}
