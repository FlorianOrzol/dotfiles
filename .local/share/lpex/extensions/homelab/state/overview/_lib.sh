#!/bin/bash
# ==============================================================================
# --- Status Overview Lib ---
# Shared constants, paths, and helper functions for all status/overview actions.
# Sourced by main.sh — do not execute directly.
# MOUNT_POOL_FAST is provided by config.conf (auto-sourced by LPEX);
# the fallback default is used when running outside LPEX.
# ==============================================================================

# ==============================================================================
# --- Configuration ---
# ==============================================================================
: "${MOUNT_POOL_FAST:=/mnt/pool_fast}"          # NFS fast pool mount — overridden by config.conf

THRESHOLD_STALE_SECONDS=28800                   # seconds before state data is considered stale (8h)

# ==============================================================================
# --- Internals ---
# Derived paths — do not edit.
# ==============================================================================
PATH_MONITORING="${MOUNT_POOL_FAST}/homelab_monitoring" # base NFS monitoring path
PATH_STATE="${PATH_MONITORING}/state"                   # live state root
PATH_STATE_HOSTS="${PATH_STATE}/hosts"                  # per-host state directories
PATH_STATE_OBSERVERS="${PATH_STATE}/observers"          # per-observer state directories
PATH_STATE_CLIENTS="${PATH_STATE}/clients"              # per-client state directories (keyed by PVE ID)
FILE_OBSERVER_HEARTBEAT="${PATH_STATE}/observer_heartbeat.json"

CMD_JQ="/usr/bin/jq"            # jq for JSON field extraction

# ==============================================================================
# --- Helpers ---
# ==============================================================================

# --- _status_check_mount ---
# @desc_short       : Returns 1 with error if the monitoring state directory is unreachable.
# @usage            : _status_check_mount || return 1
# ================================================================================
function _status_check_mount {
    # Fail early if the NFS share is not mounted or the state dir is missing
    if [[ ! -d "${PATH_STATE}" ]]; then
        ERROR "Monitoring state not accessible: ${PATH_STATE}"
        INFO  "Check NFS mount: ${MOUNT_POOL_FAST}"
        return 1
    fi
}

# --- _status_fetch_ha_ids ---
# @desc_short       : Reads HA-managed container IDs from the NFS share (written by observer).
# @usage            : _status_fetch_ha_ids || WARN "..."
# @notes            : Reads ${PATH_STATE}/ha_clients — one CT ID per line.
#                     The active observer syncs this file from its local state on change.
#                     No SSH required.
# ================================================================================
function _status_fetch_ha_ids {
    local file_ha_clients="${PATH_STATE}/ha_clients"
    local line

    # Fail if the observer has not yet synced the file to the share
    if [[ ! -f "${file_ha_clients}" ]]; then
        return 1
    fi

    # Reset and repopulate global array from the NFS copy
    HA_CONTAINER_IDS=()

    # One CT ID per line — skip blank lines
    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" ]] && continue
        HA_CONTAINER_IDS+=("${line}")
    done < "${file_ha_clients}"
}

# --- _status_fetch_ha_removed ---
# @desc_short       : Reads the ha_removed.json markers into HA_REMOVED_IDS / HA_REMOVED_DATE.
# @usage            : _status_fetch_ha_removed
# @notes            : Written by 'lpex homelab ha --remove' and '--edit'. A marker means the
#                     container was deliberately taken out of HA and is no longer restarted;
#                     it is deleted when the container is added back. Having no markers at
#                     all is the normal case — never an error.
# ================================================================================
function _status_fetch_ha_removed {
    local file_removed container_id removed_iso

    # Reset both globals — the associative array needs an explicit unset to clear
    HA_REMOVED_IDS=()
    unset HA_REMOVED_DATE
    declare -gA HA_REMOVED_DATE

    # Glob over all client dirs — only those carrying a marker were removed on purpose
    for file_removed in "${PATH_STATE_CLIENTS}"/*/ha_removed.json; do
        [[ -f "${file_removed}" ]] || continue
        container_id=$(basename "$(dirname "${file_removed}")")
        HA_REMOVED_IDS+=("${container_id}")

        # Marker stores UTC ISO — the views show a short local date instead
        removed_iso=$(${CMD_JQ} -r '.removed_iso // empty' "${file_removed}" 2>/dev/null)
        HA_REMOVED_DATE["${container_id}"]=$(date -d "${removed_iso}" '+%d.%m.' 2>/dev/null || echo "?")
    done
}

# --- _status_format_duration ---
# @desc_short       : Converts seconds to a human-readable string (e.g. "2d 4h 15m").
# @usage            : _status_format_duration <seconds>
# @parameter        : $1 | seconds | Elapsed seconds as integer.
# ================================================================================
function _status_format_duration {
    local total_seconds="$1"
    local days=$(( total_seconds / 86400 ))             # full days
    local hours=$(( (total_seconds % 86400) / 3600 ))   # remaining hours after stripping days
    local mins=$(( (total_seconds % 3600) / 60 ))       # remaining minutes after stripping hours

    # Format using only the largest non-zero unit as the lead
    if   (( days > 0 ));  then printf "%dd %dh %dm" "$days"  "$hours" "$mins"
    elif (( hours > 0 )); then printf "%dh %dm"     "$hours" "$mins"
    else                       printf "%dm"          "$mins"
    fi
}


# --- _status_format_duration_compact ---
# @desc_short       : Returns only the single largest unit (e.g. "183d", "13h", "5m").
# @usage            : _status_format_duration_compact <seconds>
# @parameter        : $1 | seconds | Elapsed seconds as integer.
# ================================================================================
function _status_format_duration_compact {
    local total_seconds="$1"
    local days=$(( total_seconds / 86400 ))
    local hours=$(( (total_seconds % 86400) / 3600 ))
    local mins=$(( (total_seconds % 3600) / 60 ))

    # Emit only the largest non-zero unit — keeps column width predictable
    if   (( days > 0 ));  then printf "%dd"  "$days"
    elif (( hours > 0 )); then printf "%dh"  "$hours"
    else                       printf "%dm"  "$mins"
    fi
}

# --- _status_calc_age_seconds ---
# @desc_short       : Returns elapsed seconds since an ISO 8601 UTC timestamp.
# @usage            : _status_calc_age_seconds <iso_timestamp>
# @parameter        : $1 | iso_timestamp | UTC timestamp e.g. "2026-06-16T04:05:47Z".
# ================================================================================
function _status_calc_age_seconds {
    local iso_timestamp="$1"
    local ts_unix now_unix
    ts_unix=$(date -d "${iso_timestamp}" +%s)   # parse ISO 8601 to unix epoch seconds
    now_unix=$(date +%s)                         # current time in epoch seconds
    echo $(( now_unix - ts_unix ))
}
