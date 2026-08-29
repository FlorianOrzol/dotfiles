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
#                     Every removal additionally leaves a permanent marker at
#                     ${PATH_SHARE_STATE}/clients/<id>/ha_removed.json — see the
#                     Removal Markers section at the bottom of this file.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# Share-side paths are derived at call time inside the functions — PATH_SHARE_STATE
# is not guaranteed to be populated yet when this file is sourced.
# ==============================================================================
FILE_REMOTE_HA_CLIENTS="/opt/homelab/state/ha_clients"      # ha_clients path on the observers (source of truth)
PATH_REMOTE_CT_STATES="/opt/homelab/state/ct_states"        # per-CT watcher state files on the observers
FILENAME_HA_REMOVED="ha_removed.json"                       # per-CT removal marker in state/clients/<id>/

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

# ==============================================================================
# --- Removal Markers ---
# A container that leaves the HA list would otherwise vanish without a trace —
# it simply stops appearing in ha_clients. These helpers keep a permanent record
# next to the container's status.json on the share, so the status views can flag
# an unprotected container without parsing observer logs.
# ==============================================================================

# --- _ha_actor ---
# @desc_short  : Prints who triggered the change, e.g. "florian@desktop".
# @usage       : actor=$(_ha_actor)
# ==============================================================================
function _ha_actor {
    printf '%s@%s' "${USER:-unknown}" "$(hostname -s)"
}

# --- _ha_mark_removed ---
# @desc_short  : Writes the permanent "removed from HA" marker for one container.
# @desc_detailed: Lives at ${PATH_SHARE_STATE}/clients/<id>/ha_removed.json and
#                 stays until the container is added back (--add / --edit), which
#                 deletes it. Share-only — the observers keep no per-client state.
# @usage       : _ha_mark_removed <container_id> <boot_position> [reason]
# @parameter   : $1 | container_id  | CT ID (numeric).
# @parameter   : $2 | boot_position | Boot position the CT held before removal (0 = unknown).
# @parameter   : $3 | reason        | Optional free text shown in the HA views.
# ==============================================================================
function _ha_mark_removed {
    local container_id="$1"
    local boot_position="$2"
    local reason="${3:-}"
    local path_client="${PATH_SHARE_STATE}/clients/${container_id}"
    local file_removed="${path_client}/${FILENAME_HA_REMOVED}"

    # Golden rule: never touch a share path while the share is down
    if [[ -z "$PATH_SHARE_STATE" ]] || ! share_mounted; then
        WARN "NFS share not mounted — removal of CT ${container_id} not recorded."
        return 1
    fi

    # A container that never reported a status has no client dir yet
    mkdir -p "$path_client" 2>/dev/null || { WARN "Cannot create ${path_client} — removal not recorded."; return 1; }

    # jq builds the JSON so a reason with quotes or newlines cannot break the file
    jq -n \
        --argjson removed_unix  "$(date +%s)" \
        --arg     removed_iso   "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --arg     actor         "$(_ha_actor)" \
        --arg     reason        "$reason" \
        --argjson last_boot_pos "$boot_position" \
        '{removed_unix: $removed_unix, removed_iso: $removed_iso, actor: $actor, reason: $reason, last_boot_pos: $last_boot_pos}' \
        > "${file_removed}.tmp" 2>/dev/null || { WARN "Cannot write ${file_removed} — removal not recorded."; return 1; }

    # Atomic swap — a status run must never read a half-written marker
    mv "${file_removed}.tmp" "$file_removed"
}

# --- _ha_clear_removed ---
# @desc_short  : Deletes the removal marker of a container that is back in HA.
# @usage       : _ha_clear_removed <container_id>
# @parameter   : $1 | container_id | CT ID (numeric).
# ==============================================================================
function _ha_clear_removed {
    local container_id="$1"
    local file_removed="${PATH_SHARE_STATE}/clients/${container_id}/${FILENAME_HA_REMOVED}"

    # Silent skip when the share is down — nothing to clean up that we could reach
    [[ -n "$PATH_SHARE_STATE" ]] && share_mounted || return 0

    rm -f "$file_removed"
}

# --- _ha_read_removed ---
# @desc_short  : Collects all removal markers as "<id>|<iso>|<actor>|<reason>" lines.
# @usage       : _ha_read_removed @return_var
# @parameter   : $1 | @return_var | Name of the array variable to fill.
# ==============================================================================
function _ha_read_removed {
    local -n return_ha_read_removed="${1#@}"
    return_ha_read_removed=()
    local file_removed container_id fields

    # Silent skip when the share is down — the caller treats this as "none known"
    [[ -n "$PATH_SHARE_STATE" ]] && share_mounted || return 0

    # Glob over all client dirs — only those with a marker are unprotected on purpose
    for file_removed in "${PATH_SHARE_STATE}"/clients/*/"${FILENAME_HA_REMOVED}"; do
        [[ -f "$file_removed" ]] || continue
        container_id=$(basename "$(dirname "$file_removed")")
        fields=$(jq -r '[.removed_iso, .actor, .reason] | join("|")' "$file_removed" 2>/dev/null) || continue
        return_ha_read_removed+=("${container_id}|${fields}")
    done
}
