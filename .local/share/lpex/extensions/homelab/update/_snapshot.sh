#!/bin/bash
# ==============================================================================
# @meta_name        : _snapshot.sh
# @desc_short       : Pre-update snapshots for 'homelab update' — sourced by
#                     update/main.sh.
# @notes            : Hosts snapshot their own root dataset inside update-os.sh
#                     (rpool/ROOT/pve-1@…_pre_update). Containers/VMs cannot
#                     snapshot themselves — snapshot-client.sh runs on the host
#                     that currently runs them. Observers (Pi, ext4 on SD card)
#                     have no snapshot facility.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
CMD_SNAPSHOT_CLIENT="/opt/homelab/bin/update/snapshot-client.sh"   # host-side pct/qm/zfs snapshot with retention

# ==============================================================================
# --- snapshot_before_update ---
# @desc_short  : Creates the rollback point of a target and records it in the summary.
# @usage       : snapshot_before_update <type> <device> <label>
# @parameter   : $1 | type   | Device type: observer | host | container | vm
# @parameter   : $2 | device | Device name or ID
# @parameter   : $3 | label  | Summary label of the target
# @exit_codes  : 0 | Snapshot taken, or not applicable for this type.
# @exit_codes  : 1 | Snapshot failed — the caller must not update the target.
# ==============================================================================
function snapshot_before_update {
    local type="$1" device="$2" label="$3"
    local host client_type

    # Only clients are snapshotted here — see file header for hosts and observers
    case "$type" in
        observer)  SUMMARY_SNAPSHOT["$label"]="n/a (ext4)"; return 0 ;;
        host)      SUMMARY_SNAPSHOT["$label"]="by update-os"; return 0 ;;
        container) client_type="ct" ;;
        vm)        client_type="vm" ;;
    esac

    # A stopped client cannot be updated either — the update reports that itself
    host=$(client_running_host "$type" "$device")
    if [[ -z "$host" ]]; then
        SUMMARY_SNAPSHOT["$label"]="-"
        return 0
    fi

    INFO "[${label}] Pre-update snapshot on ${host}..."
    if ! execute_on_device "$host" "${CMD_SNAPSHOT_CLIENT} ${client_type} ${device}"; then
        ERROR "[${label}] Snapshot failed — update skipped (no rollback point)."
        SUMMARY_SNAPSHOT["$label"]="FAILED"
        return 1
    fi
    SUMMARY_SNAPSHOT["$label"]="ok (${host})"
    return 0
}
