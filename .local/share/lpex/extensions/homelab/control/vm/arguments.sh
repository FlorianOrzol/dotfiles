#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'control/vm'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for VM power control and maintenance.
# @usage       : lpex homelab control vm --vm <id> <action>
# ==============================================================================
function arguments {
    arg_value @vm         --description "Target VM ID"                                  --fzf --option-cmd "get_vms"
    arg_flag  @start      --description "Start the VM"
    arg_flag  @stop       --description "Stop the VM"
    arg_flag  @restart    --description "Restart the VM"
    arg_flag  @maintenance --description "Enable maintenance mode (pauses HA restart)"
    arg_flag  @activate   --description "Disable maintenance mode and restore HA"
}
