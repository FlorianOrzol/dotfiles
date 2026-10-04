#!/bin/bash
# ==============================================================================
# @meta_name        : _maintenance.sh
# @desc_short       : Maintenance mode implementation for containers.
#                     Sourced by control/container/main.sh.
# ==============================================================================
# --- action_maintenance ---
# @desc_short  : Sets ha_override.json on the NFS share to pause HA for a container.
#                Container remains running — HA will not attempt to restart it.
# @usage       : action_maintenance <device>
# @parameter   : $1 | device | Container ID (e.g. 101)
# ==============================================================================
function action_maintenance {
    local device="$1"

    _ha_set_maintenance "$device"    # shared with 'setup container --delete' — see extension_global.sh
    INFO "Container '${device}' remains running — HA will not restart it during maintenance."
    OK "Maintenance enabled for container '${device}'."
}
# --- action_activate ---
# @desc_short  : Removes the HA override flag for a container from the NFS share.
# @usage       : action_activate <device>
# @parameter   : $1 | device | Container ID (e.g. 101)
# ==============================================================================
function action_activate {
    local device="$1"
    local state_file="${PATH_SHARE_STATE}/clients/${device}/ha_override.json"     # path the HA watcher reads
    if [[ ! -f "$state_file" ]]; then                                            # guard: nothing to clear
        WARN "No HA override found for container '${device}' — nothing to clear."
        return 0
    fi
    _ha_clear_maintenance "$device"    # shared with 'setup container --delete' — see extension_global.sh
    OK "Maintenance cleared for container '${device}' — HA restored."
}
