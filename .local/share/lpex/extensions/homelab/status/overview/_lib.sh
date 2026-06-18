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
FILE_OBSERVER_HEARTBEAT="${PATH_STATE}/observer_heartbeat.json"

CMD_PYTHON="/usr/bin/python3"   # python interpreter for ZFS snapshot set comparison
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
# @desc_short       : Fetches HA-managed container IDs from the leader host via SSH.
# @usage            : _status_fetch_ha_ids || WARN "..."
# @notes            : Parses /etc/pve/ha/resources.cfg — reads 'ct <id>:' entries.
#                     Populates the global HA_CONTAINER_IDS array.
#                     Called once at startup so the connection cost is paid only once.
# ================================================================================
function _status_fetch_ha_ids {
    local leader_name leader_ip ssh_user ha_raw line

    # Use the first configured host as the HA leader
    leader_name=$(get_hosts | awk '{print $1}' | head -1)
    [[ -z "${leader_name}" ]] && return 1

    # Resolve the leader's IP and SSH user from config
    leader_ip=$(get_device_ip "${leader_name}")          || return 1
    ssh_user=$(get_device_ssh_user "${leader_name}")     || return 1

    # Single SSH call to fetch the HA resource config; BatchMode prevents hanging on prompts
    ha_raw=$(ssh -o BatchMode=yes -o ConnectTimeout=5 \
        "${ssh_user}@${leader_ip}" \
        "cat /etc/pve/ha/resources.cfg 2>/dev/null") || return 1

    # Reset and repopulate the global array from the fetched config
    HA_CONTAINER_IDS=()

    # Parse lines matching "ct <id>:" — extract the numeric container ID
    while IFS= read -r line; do
        if [[ "${line}" =~ ^ct[[:space:]]+([0-9]+): ]]; then
            HA_CONTAINER_IDS+=("${BASH_REMATCH[1]}")
        fi
    done <<< "${ha_raw}"
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
