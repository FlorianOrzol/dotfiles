#!/bin/bash
# ==============================================================================
# @meta_name        : _power.sh
# @desc_short       : Power action implementations for VMs.
#                     Sourced by control/vm/main.sh.
# ==============================================================================

# --- action_power ---
# @desc_short  : Executes a power action on a VM via qm on its host.
# @usage       : action_power <device> <action>
# @parameter   : $1 | device | VM ID (e.g. 201)
# @parameter   : $2 | action | start | stop | restart
# ==============================================================================
function action_power {
    local device="$1" action="$2"
    local host qm_action="$action"

    INFO "Executing [${action}] on VM '${device}'..."

    [[ "$action" == "restart" ]] && qm_action="reboot"   # qm uses 'reboot' instead of 'restart'

    host=$(find_vm_host "$device") || return 1            # locate which host is running this VM
    execute_on_device "$host" "qm ${qm_action} ${device}"
}
