#!/bin/bash
# ==============================================================================
# @meta_name        : _maintenance.sh
# @desc_short       : Maintenance mode implementation for observers.
#                     Sourced by control/observer/main.sh.
# ==============================================================================

# --- action_maintenance ---
# @desc_short  : Sets unit-skip flags for all HA timers and stops them on the observer.
#                Standby observer will promote automatically once timers are stopped.
# @usage       : action_maintenance <device>
# @parameter   : $1 | device | Observer name (e.g. observer_1)
# ==============================================================================
function action_maintenance {
    local device="$1"
    local json='{"reason":"maintenance","set_by":"lpex"}'
    local cmds=""

    for timer in "${HA_OBSERVER_TIMERS[@]}"; do                                 # build a single SSH command covering all HA timers
        cmds+="mkdir -p ${PATH_LOCAL_UNIT_SKIP} && \
               echo '${json}' > ${PATH_LOCAL_UNIT_SKIP}/${timer} && \
               sudo systemctl stop ${timer}; "
    done

    execute_on_device "$device" "$cmds"                                         # single SSH session sets all flags and stops all timers
    INFO "Observer '${device}' is in maintenance — standby observer will promote automatically."
    OK "Maintenance enabled for '${device}'."
}

# --- action_activate ---
# @desc_short  : Removes all unit-skip flags and triggers state restore on the observer.
# @usage       : action_activate <device>
# @parameter   : $1 | device | Observer name (e.g. observer_1)
# ==============================================================================
function action_activate {
    local device="$1"

    execute_on_device "$device" \
        "rm -rf ${PATH_LOCAL_UNIT_SKIP}/* && sudo systemctl start obs-boot-state-restore.service"  # clear all flags, re-run restore

    OK "Maintenance cleared for observer '${device}' — normal operation restored."
}
