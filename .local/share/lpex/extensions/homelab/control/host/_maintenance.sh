#!/bin/bash
# ==============================================================================
# @meta_name        : _maintenance.sh
# @desc_short       : Maintenance mode implementation for hosts.
#                     Sourced by control/host/main.sh.
# ==============================================================================

# --- action_maintenance ---
# @desc_short  : Flags a host as in maintenance on the NFS share.
#                Observer reads this flag to skip backup scheduling for the host.
# @usage       : action_maintenance <device>
# @parameter   : $1 | device | Host name (e.g. host_1)
# ==============================================================================
function action_maintenance {
    local device="$1"
    local state_dir="${PATH_SHARE_STATE}/hosts/${device}"

    mkdir -p "$state_dir"                                                       # ensure state directory exists
    echo '{"reason":"maintenance","set_by":"lpex"}' > "${state_dir}/maintenance.json"  # write flag file

    INFO "Host '${device}' flagged as maintenance — observer will skip backup scheduling."
    OK "Maintenance enabled for '${device}'."
}

# --- action_activate ---
# @desc_short  : Removes the maintenance flag for a host from the NFS share.
# @usage       : action_activate <device>
# @parameter   : $1 | device | Host name (e.g. host_1)
# ==============================================================================
function action_activate {
    local device="$1"
    local state_file="${PATH_SHARE_STATE}/hosts/${device}/maintenance.json"

    if [[ ! -f "$state_file" ]]; then                                           # guard: nothing to clear
        WARN "No maintenance flag found for host '${device}' — nothing to clear."
        return 0
    fi

    rm -f "$state_file"                                                         # remove flag to restore normal scheduling
    OK "Maintenance cleared for host '${device}' — normal operation restored."
}
