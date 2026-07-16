#!/bin/bash
# ==============================================================================
# @meta_name        : _modify.sh
# @desc_short       : Modify actions (add/remove/move/edit) for the 'ha' submodule.
#                     Sourced by ha/main.sh.
# ==============================================================================

# --- action_add ---
# @desc_short  : Appends a container to the HA list (end of the boot order).
# @usage       : action_add <container_id>
# @parameter   : $1 | container_id | CT ID (numeric).
# ==============================================================================
function action_add {
    local container_id="$1"
    local -a ha_list

    # IDs are Proxmox VMIDs — reject anything non-numeric before it reaches the watcher
    [[ "$container_id" =~ ^[0-9]+$ ]] || { ERROR "Invalid container ID: '${container_id}'"; return 1; }

    _ha_read_list @ha_list || return 1

    # Duplicate guard — the watcher would start-check the CT twice per cycle
    local id
    for id in "${ha_list[@]}"; do
        [[ "$id" == "$container_id" ]] && { WARN "CT ${container_id} is already HA-managed — nothing to do."; return 0; }
    done

    ha_list+=("$container_id")
    _ha_write_list "$(printf '%s\n' "${ha_list[@]}")" "CT ${container_id} added, boot position ${#ha_list[@]}" || return 1
    OK "CT ${container_id} added to HA at boot position ${#ha_list[@]}."
}

# --- action_remove ---
# @desc_short  : Removes a container from the HA list and clears its watcher state.
# @usage       : action_remove <container_id>
# @parameter   : $1 | container_id | CT ID (numeric).
# ==============================================================================
function action_remove {
    local container_id="$1"
    local -a ha_list new_list=()
    local found=0 id observer ip user

    _ha_read_list @ha_list || return 1

    # Rebuild the list without the target ID — order of the rest stays untouched
    for id in "${ha_list[@]}"; do
        if [[ "$id" == "$container_id" ]]; then
            found=1
        else
            new_list+=("$id")
        fi
    done

    (( found )) || { WARN "CT ${container_id} is not HA-managed — nothing to remove."; return 0; }

    _ha_write_list "$(printf '%s\n' "${new_list[@]}")" "CT ${container_id} removed" || return 1

    # Clear the watcher's per-CT state file on both observers — best effort, a leftover
    # file is harmless (the watcher only reads states for listed IDs)
    for observer in "${OBSERVERS[@]}"; do
        ip=$(get_device_ip "$observer")         || continue
        user=$(get_device_ssh_user "$observer") || continue
        ssh "${SSH_OPTS_HA[@]}" "${user}@${ip}" "rm -f ${PATH_REMOTE_CT_STATES}/${container_id}" 2>/dev/null
    done

    OK "CT ${container_id} removed from HA."
    INFO "A running container keeps running — HA just no longer restarts it."
}

# --- action_move ---
# @desc_short  : Moves a container to a new position in the boot order.
# @usage       : action_move <container_id> <position>
# @parameter   : $1 | container_id | CT ID (numeric).
# @parameter   : $2 | position     | Target boot position (1-based).
# ==============================================================================
function action_move {
    local container_id="$1"
    local position="$2"
    local -a ha_list new_list=()
    local found=0 id index=0

    # Position must be a positive number — 0 or text would corrupt the rebuild below
    [[ "$position" =~ ^[1-9][0-9]*$ ]] || { ERROR "Invalid position: '${position}' (1-based number required)."; return 1; }

    _ha_read_list @ha_list || return 1

    # Take the target ID out of the list first — its old slot must not shift the target position
    for id in "${ha_list[@]}"; do
        if [[ "$id" == "$container_id" ]]; then
            found=1
        else
            new_list+=("$id")
        fi
    done

    (( found )) || { ERROR "CT ${container_id} is not HA-managed — add it first (--add)."; return 1; }

    # Clamp to list end — asking for position 99 in a list of 9 means "last"
    (( position > ${#new_list[@]} + 1 )) && position=$(( ${#new_list[@]} + 1 ))

    # Rebuild with the ID spliced in at the requested slot (array index = position - 1)
    local -a final_list=()
    for id in "${new_list[@]}"; do
        (( index == position - 1 )) && final_list+=("$container_id")
        final_list+=("$id")
        (( index++ ))
    done
    # Target position is the end of the list — append after the loop
    (( position - 1 >= ${#new_list[@]} )) && final_list+=("$container_id")

    _ha_write_list "$(printf '%s\n' "${final_list[@]}")" "CT ${container_id} moved to boot position ${position}" || return 1
    OK "CT ${container_id} moved to boot position ${position}."
}

# --- action_edit ---
# @desc_short  : Opens the boot order in $EDITOR, validates and deploys the result.
# @usage       : action_edit
# ==============================================================================
function action_edit {
    local -a ha_list
    local file_tmp id line

    _ha_read_list @ha_list || return 1

    # Editable working copy with a usage hint — comments are stripped on save
    file_tmp=$(mktemp /tmp/lpex_ha_clients.XXXXXX)
    {
        echo "# HA clients — one CT ID per line, line order = boot order."
        echo "# Comments and blank lines are ignored."
        printf '%s\n' "${ha_list[@]}"
    } > "$file_tmp"

    # Block interactive edit without a terminal editor configured
    "${EDITOR:-vi}" "$file_tmp" || { rm -f "$file_tmp"; ERROR "Editor aborted — list unchanged."; return 1; }

    # Re-parse the edited file with the same normalization the watcher uses
    local -a new_list=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        id="${line%%#*}"                    # strip comments
        id="${id//[[:space:]]/}"            # trim whitespace
        [[ -z "$id" ]] && continue          # skip blank/comment-only lines
        # One bad line aborts the whole save — a broken list must never reach the watcher
        [[ "$id" =~ ^[0-9]+$ ]] || { rm -f "$file_tmp"; ERROR "Invalid line: '${line}' — list unchanged."; return 1; }
        new_list+=("$id")
    done < "$file_tmp"
    rm -f "$file_tmp"

    # An empty result is almost always an accident — require explicit --remove instead
    (( ${#new_list[@]} == 0 )) && { ERROR "Edited list is empty — use --remove to clear entries."; return 1; }

    # Skip the deploy when nothing actually changed
    if [[ "$(printf '%s\n' "${new_list[@]}")" == "$(printf '%s\n' "${ha_list[@]}")" ]]; then
        INFO "No changes — list untouched."
        return 0
    fi

    _ha_write_list "$(printf '%s\n' "${new_list[@]}")" "boot order edited (${#new_list[@]} CTs)" || return 1
    OK "Boot order updated (${#new_list[@]} CTs)."
}
