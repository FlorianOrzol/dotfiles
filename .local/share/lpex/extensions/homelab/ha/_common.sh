#!/bin/bash
# ==============================================================================
# @meta_name        : _common.sh
# @desc_short       : Shared paths and read/write helpers for the 'ha' submodule.
#                     Sourced by ha/main.sh.
# @desc_detailed    : The ha_clients list lives on the observers under
#                     /opt/homelab/state/ha_clients (source of truth — the HA
#                     watcher must stay decision-capable without NFS). The active
#                     watcher mirrors it to ${PATH_SHARE_STATE}/ha_clients; LPEX
#                     reads NFS-first and writes observers + share on changes.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# Share-side paths are derived at call time inside the functions — PATH_SHARE_STATE
# is not guaranteed to be populated yet when this file is sourced.
# ==============================================================================
FILE_REMOTE_HA_CLIENTS="/opt/homelab/state/ha_clients"      # ha_clients path on the observers (source of truth)
PATH_REMOTE_CT_STATES="/opt/homelab/state/ct_states"        # per-CT watcher state files on the observers

SSH_OPTS_HA=(-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes)

# --- _ha_read_list ---
# @desc_short  : Reads the ha_clients boot order into an array — NFS-first, SSH fallback.
# @usage       : _ha_read_list @return_var
# @parameter   : $1 | @return_var | Name of the array variable to fill (one CT ID per element).
# ==============================================================================
function _ha_read_list {
    local -n return_ha_read_list="${1#@}"
    return_ha_read_list=()
    local raw="" id ip user
    local file_share_ha="${PATH_SHARE_STATE}/ha_clients"    # runtime-derived — see Script Internals note

    # NFS-first: the share mirror avoids SSH in the common read path
    if [[ -n "$PATH_SHARE_STATE" && -f "$file_share_ha" ]]; then
        raw=$(<"$file_share_ha")
    else
        # Share unavailable — fall back to the primary observer via SSH
        ip=$(get_device_ip "$OBSERVER_PRIMARY")         || return 1
        user=$(get_device_ssh_user "$OBSERVER_PRIMARY") || return 1
        raw=$(ssh "${SSH_OPTS_HA[@]}" "${user}@${ip}" "cat ${FILE_REMOTE_HA_CLIENTS}" 2>/dev/null) || {
            ERROR "ha_clients not readable — share unmounted and ${OBSERVER_PRIMARY} unreachable."
            return 1
        }
    fi

    # Normalize each line: strip comments/whitespace, keep only non-empty IDs
    while IFS= read -r id || [[ -n "$id" ]]; do
        id="${id%%#*}"                      # strip optional '# comment' suffix
        id="${id//[[:space:]]/}"            # trim all whitespace around the ID
        [[ -n "$id" ]] && return_ha_read_list+=("$id")
    done <<< "$raw"
}

# --- _ha_write_list ---
# @desc_short  : Writes the boot order to both observers and the NFS share.
# @desc_detailed: Primary observer is mandatory (the active watcher reads locally);
#                 standby observer is best effort (may sleep — warn only); the share
#                 copy is written directly so displays are consistent immediately
#                 instead of waiting for the watcher's next sync cycle.
# @usage       : _ha_write_list <list_content> <change_description>
# @parameter   : $1 | list_content       | Full new list, newline separated CT IDs.
# @parameter   : $2 | change_description | Short text for the observer event log.
# ==============================================================================
function _ha_write_list {
    local list_content="$1"
    local change_description="$2"
    local observer ip user
    local file_share_ha="${PATH_SHARE_STATE}/ha_clients"    # runtime-derived — see Script Internals note

    for observer in "${OBSERVERS[@]}"; do
        ip=$(get_device_ip "$observer")         || return 1
        user=$(get_device_ssh_user "$observer") || return 1

        # Atomic remote write: tmp file + mv prevents the watcher reading a partial list;
        # ssh stderr suppressed — the WARN/ERROR below reports the failure cleanly
        if printf '%s\n' "$list_content" | ssh "${SSH_OPTS_HA[@]}" "${user}@${ip}" \
                "cat > ${FILE_REMOTE_HA_CLIENTS}.tmp && mv ${FILE_REMOTE_HA_CLIENTS}.tmp ${FILE_REMOTE_HA_CLIENTS}" 2>/dev/null; then
            OK "ha_clients written → ${observer}"
        else
            # Only the primary is mandatory — its watcher acts on the list every 60s
            if [[ "$observer" == "$OBSERVER_PRIMARY" ]]; then
                ERROR "Write to ${observer} failed — aborting (primary is the source of truth)."
                return 1
            fi
            WARN "Write to ${observer} failed (offline?) — sync it manually when it is back."
        fi
    done

    # Direct share update for immediate display consistency (watcher would sync within 60s)
    if [[ -n "$PATH_SHARE_STATE" ]] && share_mounted; then
        printf '%s\n' "$list_content" > "$file_share_ha"
    else
        WARN "NFS share not mounted — share copy will be synced by the watcher."
    fi

    # Make the change visible in the observer's event history (fire-and-forget)
    observer_log_event "LPEX: ha_clients updated (${change_description})" "OK"
}
