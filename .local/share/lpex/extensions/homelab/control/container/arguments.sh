#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'control/container'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for container power control and maintenance.
# @usage       : lpex homelab control container --container <id> <action>
# ==============================================================================
function arguments {
    arg_value @container  --description "Target container ID"                           --fzf --option-cmd "get_containers"
    arg_flag  @start      --description "Start the container"
    arg_flag  @stop       --description "Stop the container"
    arg_flag  @restart    --description "Restart the container"
    arg_flag  @maintenance --description "Enable maintenance mode (pauses HA restart)"
    arg_flag  @activate   --description "Disable maintenance mode and restore HA"
}
