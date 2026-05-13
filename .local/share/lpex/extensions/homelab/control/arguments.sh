#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'control'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for device power control and maintenance.
# @usage       : lpex homelab control <device> <action>
#
# @devices     : --host | --container | --vm | --observer
# @actions     : --start | --stop | --restart | --maintenance | --activate
# ==============================================================================
function arguments {
    # Device selection — exactly one required
    arg_value @host      --description "Target host"      --fzf --option-cmd "get_hosts"
    arg_value @observer  --description "Target observer"  --fzf --option-cmd "get_observers"
    arg_value @container --description "Target container" --fzf --option-cmd "get_containers"
    arg_value @vm        --description "Target VM"        --fzf --option-cmd "get_vms"

    # Power actions — mutually exclusive
    arg_flag @start   --description "Start the device"
    arg_flag @stop    --description "Stop the device"
    arg_flag @restart --description "Restart the device"

    # Maintenance actions — mutually exclusive
    arg_flag @maintenance --description "Enable maintenance mode (pauses HA / backup scheduling)"
    arg_flag @activate    --description "Disable maintenance mode and restore normal operation"
}
