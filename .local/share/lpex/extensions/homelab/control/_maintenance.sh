#!/bin/bash
# ==============================================================================
# @meta_name        : _maintenance.sh
# @desc_short       : Maintenance mode implementation (enable / disable).
#                     Sourced by control/main.sh.
# ==============================================================================

# --- action_maintenance ---
# @desc_short  : Enables maintenance mode for a device.
# @usage       : action_maintenance <type> <device>
# @parameter   : $1 | type   | Device type: host | observer | container | vm
# @parameter   : $2 | device | Device name or ID
# ==============================================================================
function action_maintenance {
    local type="$1" device="$2"

    case "$type" in
        observer)  _maintenance_observer  "$device" ;;
        host)      _maintenance_host      "$device" ;;
        container) _maintenance_ct_vm     "container" "$device" ;;
        vm)        _maintenance_ct_vm     "vm"        "$device" ;;
    esac
}

# --- action_activate ---
# @desc_short  : Disables maintenance mode and restores normal operation.
# @usage       : action_activate <type> <device>
# @parameter   : $1 | type   | Device type: host | observer | container | vm
# @parameter   : $2 | device | Device name or ID
# ==============================================================================
function action_activate {
    local type="$1" device="$2"

    case "$type" in
        observer)  _activate_observer  "$device" ;;
        host)      _activate_host      "$device" ;;
        container) _activate_ct_vm     "container" "$device" ;;
        vm)        _activate_ct_vm     "vm"        "$device" ;;
    esac
}

# ==============================================================================
# --- Maintenance Implementations ---
# ==============================================================================

# --- _maintenance_observer ---
# @desc_short  : Sets unit-skip flags for all HA timers and stops them on the observer.
# ==============================================================================
function _maintenance_observer {
    local device="$1"
    local json='{"reason":"maintenance","set_by":"lpex"}'
    local cmds=""

    # Build a single SSH command that sets a skip-flag file and stops each HA timer
    for timer in "${HA_OBSERVER_TIMERS[@]}"; do
        cmds+="mkdir -p ${PATH_LOCAL_UNIT_SKIP} && \
               echo '${json}' > ${PATH_LOCAL_UNIT_SKIP}/${timer} && \
               sudo systemctl stop ${timer}; "
    done

    execute_on_device "$device" "$cmds"
    INFO "Observer '${device}' is in maintenance — standby observer will promote automatically."
    OK "Maintenance enabled for '${device}'."
}

# --- _maintenance_host ---
# @desc_short  : Writes maintenance.json to the NFS share state for this host.
#                Observer reads this flag to skip backup scheduling for the host.
# ==============================================================================
function _maintenance_host {
    local device="$1"
    local state_dir="${PATH_SHARE_STATE}/hosts/${device}"
    local state_file="${state_dir}/maintenance.json"

    # Create state directory if missing
    mkdir -p "$state_dir"
    echo '{"reason":"maintenance","set_by":"lpex"}' > "$state_file"

    INFO "Host '${device}' flagged as maintenance — observer will skip backup scheduling."
    OK "Maintenance enabled for '${device}'."
}

# --- _maintenance_ct_vm ---
# @desc_short  : Writes ha_override.json to the NFS share state to pause HA for a container or VM.
# ==============================================================================
function _maintenance_ct_vm {
    local type="$1" device="$2"
    local state_dir="${PATH_SHARE_STATE}/${type}_${device}"
    local state_file="${state_dir}/ha_override.json"

    # Create state directory if missing
    mkdir -p "$state_dir"
    echo '{"mode":"maintenance","set_by":"lpex"}' > "$state_file"

    INFO "${type^} '${device}' remains running — HA will not restart it during maintenance."
    OK "Maintenance enabled for '${device}'."
}

# ==============================================================================
# --- Activate Implementations ---
# ==============================================================================

# --- _activate_observer ---
# @desc_short  : Removes all unit-skip flags and triggers state restore on the observer.
# ==============================================================================
function _activate_observer {
    local device="$1"

    execute_on_device "$device" \
        "rm -rf ${PATH_LOCAL_UNIT_SKIP}/* && sudo systemctl start obs-boot-state-restore.service"

    OK "Maintenance cleared for observer '${device}' — normal operation restored."
}

# --- _activate_host ---
# @desc_short  : Removes the maintenance.json flag from the NFS share for this host.
# ==============================================================================
function _activate_host {
    local device="$1"
    local state_file="${PATH_SHARE_STATE}/hosts/${device}/maintenance.json"

    # Warn if file does not exist — activate called without prior maintenance
    if [[ ! -f "$state_file" ]]; then
        WARN "No maintenance flag found for host '${device}' — nothing to clear."
        return 0
    fi

    rm -f "$state_file"
    OK "Maintenance cleared for host '${device}' — normal operation restored."
}

# --- _activate_ct_vm ---
# @desc_short  : Removes the ha_override.json flag from the NFS share for a container or VM.
# ==============================================================================
function _activate_ct_vm {
    local type="$1" device="$2"
    local state_file="${PATH_SHARE_STATE}/${type}_${device}/ha_override.json"

    # Warn if file does not exist — activate called without prior maintenance
    if [[ ! -f "$state_file" ]]; then
        WARN "No HA override found for ${type} '${device}' — nothing to clear."
        return 0
    fi

    rm -f "$state_file"
    OK "Maintenance cleared for ${type} '${device}' — HA restored."
}
