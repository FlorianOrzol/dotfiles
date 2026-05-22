#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Manages homelab.conf and homelab_functions.sh.
#                     Edit locally, fetch from a device, or push to all devices.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
FILE_REMOTE_CONF="/opt/homelab/homelab.conf"              # path on all devices
FILE_REMOTE_FUNCTIONS="/opt/homelab/homelab_functions.sh" # path on all devices

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"  # common SSH flags

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates that exactly one action is given, then routes to it.
# ==============================================================================
function extension_start {
    # PATH_EXTENSION_DATA is set by the LPEX auto-loader after main.sh is sourced,
    # so path-dependent variables must be assigned here, not at file scope.
    FILE_LOCAL_CONF="${PATH_EXTENSION_DATA}/config.conf"
    FILE_LOCAL_FUNCTIONS="${PATH_EXTENSION_DATA}/homelab_functions.sh"
    FILE_OBSERVER_LEADER_HOMELAB_CONF="${PATH_EXTENSION_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"
    FILE_OBSERVER_LEADER_HOMELAB_FUNCTIONS="${PATH_EXTENSION_DATA}/mirror/observer/observer_1/opt/homelab/homelab_functions.sh"

    local action_count=0

    # Count provided action flags — only one is allowed at a time.
    [[ -n "$ARG_EDIT" ]]  && (( action_count++ ))
    [[ -n "$ARG_FETCH" ]] && (( action_count++ ))
    [[ -n "$ARG_PUSH" ]]  && (( action_count++ ))

    # Require at least one action.
    if (( action_count == 0 )); then
        ERROR "No action specified. Use --edit, --fetch <device>, or --push."
        return 1
    fi

    # Multiple actions in one call are not supported — intent would be ambiguous.
    if (( action_count > 1 )); then
        ERROR "Only one action at a time: --edit, --fetch, or --push."
        return 1
    fi

    # Route to the matching action.
    [[ -n "$ARG_EDIT" ]]  && { action_edit;  return $?; }
    [[ -n "$ARG_FETCH" ]] && { action_fetch; return $?; }
    [[ -n "$ARG_PUSH" ]]  && { action_push;  return $?; }
}

# ==============================================================================
# --- action_edit ---
# @desc_short  : Opens the local config.conf in $EDITOR.
# ==============================================================================
function action_edit {
    # Local file must exist before editing.
    if [[ ! -f "$FILE_LOCAL_CONF" ]]; then
        ERROR "Local config not found: ${FILE_LOCAL_CONF}"
        INFO "Run --fetch first to pull it from a device."
        return 1
    fi

    # Fall back to vi if $EDITOR is not set.
    local editor="${EDITOR:-vi}"

    INFO "Opening ${FILE_LOCAL_CONF} with ${editor}..."
    "$editor" "$FILE_LOCAL_CONF"
}

# ==============================================================================
# --- action_fetch ---
# @desc_short  : Fetches homelab.conf from a device and saves it as local config.conf.
# ==============================================================================
function action_fetch {
    local device="$ARG_FETCH"
    local ip user

    # Resolve device connection details from config arrays.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    INFO "Fetching '${FILE_REMOTE_CONF}' from '${device}'..."

    if ! ssh ${SSH_OPTS} "${user}@${ip}" "cat '${FILE_REMOTE_CONF}'" > "$FILE_LOCAL_CONF"; then
        ERROR "Fetch failed from '${device}'."
        return 1
    fi

    OK "Fetched '${FILE_REMOTE_CONF}' from '${device}' → ${FILE_LOCAL_CONF}"
}

# ==============================================================================
# --- action_push ---
# @desc_short  : Pushes homelab.conf + homelab_functions.sh to all reachable devices.
# @notes       : Step 1 — updates the observer_1 leader mirror from local sources.
#                Step 2 — syncs leader mirror to all other device mirrors (local).
#                Step 3 — pushes both files to all online devices.
#                Offline devices are skipped — they pull on next boot.
# ==============================================================================
function action_push {
    # Both local source files must exist.
    if [[ ! -f "$FILE_LOCAL_CONF" ]]; then
        ERROR "Local config not found: ${FILE_LOCAL_CONF}"
        INFO "Run --fetch or --edit first."
        return 1
    fi
    if [[ ! -f "$FILE_LOCAL_FUNCTIONS" ]]; then
        ERROR "Local functions file not found: ${FILE_LOCAL_FUNCTIONS}"
        return 1
    fi

    # Step 1: Update the observer_1 leader mirror from local sources.
    INFO "Updating leader mirror (observer_1)..."
    cp "$FILE_LOCAL_CONF"      "$FILE_OBSERVER_LEADER_HOMELAB_CONF"      || { ERROR "Failed to update leader mirror (homelab.conf).";      return 1; }
    cp "$FILE_LOCAL_FUNCTIONS" "$FILE_OBSERVER_LEADER_HOMELAB_FUNCTIONS" || { ERROR "Failed to update leader mirror (homelab_functions.sh)."; return 1; }

    # Step 2: Sync both files from leader mirror to all other device mirrors.
    INFO "Syncing to all device mirrors..."
    _sync_mirrors

    # Step 3: Push both files to all online devices.
    local all_observers=() all_hosts=()
    while IFS= read -r d; do all_observers+=("$d"); done < <(get_observers)  # collect all observers
    while IFS= read -r d; do all_hosts+=("$d"); done < <(get_hosts)          # collect all hosts

    local pushed=0 skipped=0
    for device in "${all_observers[@]}" "${all_hosts[@]}"; do
        if _device_reachable "$device"; then
            _push_to_device "$device" && (( pushed++ )) || true
        else
            WARN "Device '${device}' not reachable — skipping (will pull on next boot)."
            (( skipped++ ))
        fi
    done

    INFO "Push complete: ${pushed} device(s) updated, ${skipped} skipped (offline)."
}

# --- _sync_mirrors ---
# @desc_short  : Copies homelab.conf + homelab_functions.sh from leader mirror to all device mirrors.
# ==============================================================================
function _sync_mirrors {
    local observers=() hosts=()
    while IFS= read -r d; do observers+=("$d"); done < <(get_observers)
    while IFS= read -r d; do hosts+=("$d"); done < <(get_hosts)

    # Sync to each observer mirror (observer_1 already updated in step 1 — cp is idempotent).
    for device in "${observers[@]}"; do
        local mirror_base="${PATH_EXTENSION_DATA}/mirror/observer/${device}/opt/homelab"
        [[ ! -d "$mirror_base" ]] && continue
        cp "$FILE_OBSERVER_LEADER_HOMELAB_CONF"      "${mirror_base}/homelab.conf"
        cp "$FILE_OBSERVER_LEADER_HOMELAB_FUNCTIONS" "${mirror_base}/homelab_functions.sh"
    done

    # Sync to each host mirror.
    for device in "${hosts[@]}"; do
        local mirror_base="${PATH_EXTENSION_DATA}/mirror/host/${device}/opt/homelab"
        [[ ! -d "$mirror_base" ]] && continue
        cp "$FILE_OBSERVER_LEADER_HOMELAB_CONF"      "${mirror_base}/homelab.conf"
        cp "$FILE_OBSERVER_LEADER_HOMELAB_FUNCTIONS" "${mirror_base}/homelab_functions.sh"
    done
}

# --- _device_reachable ---
# @desc_short  : Returns 0 if the device responds to SSH.
# @parameter   : $1 | device | Device name
# ==============================================================================
function _device_reachable {
    local device="$1"
    local ip user
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1
    ssh ${SSH_OPTS} "${user}@${ip}" true 2>/dev/null
}

# --- _push_to_device ---
# @desc_short  : Pushes homelab.conf + homelab_functions.sh to a single device.
# @parameter   : $1 | device | Device name (observer or host)
# ==============================================================================
function _push_to_device {
    local device="$1"
    local ip user sudo_prefix

    # Resolve device connection details from config.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    # Hosts SSH as root (no sudo needed). Observers SSH as fadmin (sudo required).
    [[ "$user" == "root" ]] && sudo_prefix="" || sudo_prefix="sudo "

    # Push homelab.conf.
    if ! ssh ${SSH_OPTS} "${user}@${ip}" \
            "${sudo_prefix}tee '${FILE_REMOTE_CONF}' > /dev/null" < "$FILE_OBSERVER_LEADER_HOMELAB_CONF"; then
        ERROR "Push of homelab.conf failed to '${device}'."
        return 1
    fi

    # Push homelab_functions.sh + ensure executable.
    if ! ssh ${SSH_OPTS} "${user}@${ip}" \
            "${sudo_prefix}tee '${FILE_REMOTE_FUNCTIONS}' > /dev/null" < "$FILE_OBSERVER_LEADER_HOMELAB_FUNCTIONS"; then
        ERROR "Push of homelab_functions.sh failed to '${device}'."
        return 1
    fi
    ssh ${SSH_OPTS} "${user}@${ip}" "${sudo_prefix}chmod +x '${FILE_REMOTE_FUNCTIONS}'" 2>/dev/null || true

    OK "Pushed homelab.conf + homelab_functions.sh → '${device}'"
}
