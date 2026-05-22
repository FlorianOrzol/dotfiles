#!/bin/bash
# ==============================================================================
# @meta_name        : _power.sh
# @desc_short       : Power action implementations for containers.
#                     Sourced by control/container/main.sh.
# ==============================================================================

# --- action_power ---
# @desc_short  : Executes a power action on a container via pct on its host.
# @usage       : action_power <device> <action>
# @parameter   : $1 | device | Container ID (e.g. 101)
# @parameter   : $2 | action | start | stop | restart
# ==============================================================================
function action_power {
    local device="$1" action="$2"
    local host pct_action="$action"

    INFO "Executing [${action}] on container '${device}'..."

    [[ "$action" == "restart" ]] && pct_action="reboot"   # pct uses 'reboot' instead of 'restart'

    host=$(find_container_host "$device") || return 1      # locate which host is running this container
    execute_on_device "$host" "pct ${pct_action} ${device}"
}
