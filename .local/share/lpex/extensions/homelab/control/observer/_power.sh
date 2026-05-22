#!/bin/bash
# ==============================================================================
# @meta_name        : _power.sh
# @desc_short       : Power action implementations for observers.
#                     Sourced by control/observer/main.sh.
# ==============================================================================

# --- action_power ---
# @desc_short  : Executes a power action on an observer.
# @usage       : action_power <device> <action>
# @parameter   : $1 | device | Observer name (e.g. observer_1)
# @parameter   : $2 | action | restart
# @notes       : Only restart is supported remotely. Start requires physical access or WOL.
# ==============================================================================
function action_power {
    local device="$1" action="$2"

    INFO "Executing [${action}] on observer '${device}'..."

    case "$action" in
        restart)
            execute_on_device "$device" "sudo reboot"  # fadmin requires sudo for system reboot
            ;;
    esac
}
