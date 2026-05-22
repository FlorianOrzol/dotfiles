#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'control/host'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for host power control and maintenance.
# @usage       : lpex homelab control host --host <name> <action>
# ==============================================================================
function arguments {
    arg_value @host       --description "Target host"                                  --fzf --option-cmd "get_hosts"
    arg_flag  @start      --description "Wake the host via WOL (routed through observer)"
    arg_flag  @restart    --description "Restart the host"
    arg_flag  @shutdown   --description "Shut down the host"
    arg_flag  @maintenance --description "Enable maintenance mode (pauses backup scheduling)"
    arg_flag  @activate   --description "Disable maintenance mode and restore normal operation"
}
