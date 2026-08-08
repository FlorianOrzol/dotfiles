#!/bin/bash
# ==============================================================================
# @meta_name        : _run.sh
# @desc_short       : Update execution logic — sourced by update/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
CMD_DRY_RUN="apt list --upgradable 2>/dev/null | grep -v Listing || echo no upgradable packages"  # lists upgradable packages; echo-fallback — grep exits 1 on empty list which is not an error; no quotes in pattern — cmd is wrapped in single quotes for SSH
CMD_UPDATE="/opt/homelab/bin/update/update-os.sh"                       # runs full OS update (apt dist-upgrade)
CMD_STATUS_HOST="/opt/homelab/bin/hosts/get-host-status.sh"             # refreshes host status.json on the NFS share
CMD_STATUS_OBSERVER="/opt/homelab/bin/observer/obs-health.sh"           # refreshes observer status.json on the NFS share

# ==============================================================================
# --- update_device ---
# @desc_short  : Runs update (or dry-run) on a single device, then refreshes
#                the device's status.json on the NFS share.
# @notes       : Patches (apply-patches.sh) are intentionally not wired here —
#                they belong to the planned 'setup patches' submodule.
# @parameter   : $1 | type         | Device type: observer | host | container | vm
# @parameter   : $2 | device       | Device name or ID
# @parameter   : $3 | dry_run      | Non-empty = show upgradable packages only, no changes
# @parameter   : $4 | reboot       | Non-empty = reboot the device when apt demands it
# @parameter   : $5 | reboot_force | Non-empty = reboot the device unconditionally
# ==============================================================================
function update_device {
    local type="$1" device="$2" dry_run="$3" reboot="$4" reboot_force="$5"
    local cmd_update

    INFO "[${device}] Starting update..."

    # Dry-run only lists upgradable packages without touching the system.
    # Full run calls update-os.sh which runs apt update + apt dist-upgrade;
    # --reboot-force schedules a delayed reboot unconditionally (wins over
    # --reboot), --reboot only when apt demands one.
    if [[ -n "$dry_run" ]]; then
        cmd_update="$CMD_DRY_RUN"
    elif [[ -n "$reboot_force" ]]; then
        cmd_update="${CMD_UPDATE} --reboot-force"
    elif [[ -n "$reboot" ]]; then
        cmd_update="${CMD_UPDATE} --reboot"
    else
        cmd_update="$CMD_UPDATE"
    fi

    # Abort with a clear error if the update command fails.
    if ! _execute_update "$type" "$device" "$cmd_update"; then
        ERROR "[${device}] Update failed."
        return 1
    fi

    OK "[${device}] Update complete."

    # Refresh the status view right away — the daily health timer (06:05) would
    # otherwise show stale pre-update data until the next morning. Dry-runs
    # change nothing, so there is nothing to refresh.
    [[ -z "$dry_run" ]] && _refresh_device_status "$type" "$device"
    return 0
}

# --- shutdown_woken_host ---
# @desc_short  : Powers a host down again that this run woke up for the update.
# @desc_detailed: Restores the pre-update power state — a host that was off before
#                 must not be left running afterwards. Delegates to host-shutdown.sh
#                 on the primary observer, the same path 'control host power' uses,
#                 so the observer stays the single power authority and logs the event.
# @parameter   : $1 | device | Logical host name
# ==============================================================================
function shutdown_woken_host {
    local device="$1"

    INFO "[${device}] Was offline before the update — powering down again via ${OBSERVER_PRIMARY}..."

    # Best-effort: a failed power-down only leaves the host running, which is harmless
    if ! execute_on_device "$OBSERVER_PRIMARY" "/opt/homelab/bin/hosts/host-shutdown.sh ${device}"; then
        WARN "[${device}] Power-down failed — host stays online."
        return 1
    fi

    OK "[${device}] Powered down again."
}

# --- _refresh_device_status ---
# @desc_short  : Re-runs the status collector of a device so the NFS share
#                reflects the post-update state immediately.
# @notes       : Best-effort — a failed refresh must not fail the update itself.
#                Observers run their collector as fadmin (no sudo!) to keep the
#                share file ownership identical to the daily timer runs.
#                Containers and VMs have no status collector — nothing to do.
# @parameter   : $1 | type   | Device type: observer | host | container | vm
# @parameter   : $2 | device | Device name or ID
# ==============================================================================
function _refresh_device_status {
    local type="$1" device="$2"

    case "$type" in
        # Host collector self-heals its NFS mounts (ensure_share_mounted) — no
        # observer-side mount trigger needed here
        host)      INFO "[${device}] Refreshing status.json on the share..."
                   execute_on_device "$device" "$CMD_STATUS_HOST" \
                       || WARN "[${device}] Status refresh failed — next health timer run will catch up." ;;
        observer)  INFO "[${device}] Refreshing status.json on the share..."
                   execute_on_device "$device" "$CMD_STATUS_OBSERVER" \
                       || WARN "[${device}] Status refresh failed — next health timer run will catch up." ;;
        # Containers and VMs have no status collector on the share yet.
        *)         return 0 ;;
    esac
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
