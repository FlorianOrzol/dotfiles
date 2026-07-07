#!/bin/bash
# ==============================================================================
# @meta_name        : _run.sh
# @desc_short       : Update execution logic — sourced by update/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
CMD_DRY_RUN="apt list --upgradable 2>/dev/null | grep -v Listing"       # lists upgradable packages; no quotes in pattern — cmd is wrapped in single quotes for SSH
CMD_UPDATE="/opt/homelab/bin/update/update-os.sh"                       # runs full OS update (apt upgrade)

# ==============================================================================
# --- update_device ---
# @desc_short  : Runs update (or dry-run) on a single device.
# @notes       : Patches (apply-patches.sh) are intentionally not wired here —
#                they belong to the planned 'setup patches' submodule.
# @parameter   : $1 | type     | Device type: observer | host | container | vm
# @parameter   : $2 | device   | Device name or ID
# @parameter   : $3 | dry_run  | Non-empty = show upgradable packages only, no changes
# ==============================================================================
function update_device {
    local type="$1" device="$2" dry_run="$3"
    local cmd_update

    INFO "[${device}] Starting update..."

    # Dry-run only lists upgradable packages without touching the system.
    # Full run calls update-os.sh which runs apt update + apt upgrade.
    if [[ -n "$dry_run" ]]; then
        cmd_update="$CMD_DRY_RUN"
    else
        cmd_update="$CMD_UPDATE"
    fi

    # Abort with a clear error if the update command fails.
    if ! _execute_update "$type" "$device" "$cmd_update"; then
        ERROR "[${device}] Update failed."
        return 1
    fi

    OK "[${device}] Update complete."
}

# --- _execute_update ---
# @desc_short  : Dispatches a shell command to the correct execute helper by device type.
# @parameter   : $1 | type   | Device type: observer | host | container | vm
# @parameter   : $2 | device | Device name or ID
# @parameter   : $3 | cmd    | Command to execute on the target device
# ==============================================================================
function _execute_update {
    local type="$1" device="$2" cmd="$3"

    # Route to the correct helper — containers and VMs require indirection via their host.
    # Observers SSH as fadmin — apt and the update scripts need sudo there;
    # hosts SSH as root, containers/VMs execute as root via pct/qm.
    case "$type" in
        observer)      execute_on_device    "$device" "sudo ${cmd}" ;;
        host)          execute_on_device    "$device" "$cmd" ;;
        container)     execute_on_container "$device" "$cmd" ;;
        vm)            execute_on_vm        "$device" "$cmd" ;;
        # Unknown type indicates a bug in the caller — surface it immediately.
        *)             ERROR "Unknown device type: '${type}'"; return 1 ;;
    esac
}
