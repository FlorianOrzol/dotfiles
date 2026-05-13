#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Manages the global homelab variable file (homelab.conf).
#                     Edit locally, fetch from a device, or push to devices.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
FILE_LOCAL_CONF="${PATH_EXTENSION_DATA}/config.conf"   # local desktop copy of homelab.conf
FILE_REMOTE_CONF="/opt/homelab/homelab.conf"           # path on all devices

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"  # common SSH flags

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates that exactly one action is given, then routes to it.
# ==============================================================================
function extension_start {
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
# @notes       : Overwrites the local file. The device must be a host or observer.
# ==============================================================================
function action_fetch {
    local device="$ARG_FETCH"
    local ip user

    # Resolve device connection details from config arrays.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    INFO "Fetching '${FILE_REMOTE_CONF}' from '${device}'..."

    # Direct SSH/tar — pipe remote file content straight into the local destination.
    if ! ssh ${SSH_OPTS} "${user}@${ip}" "cat '${FILE_REMOTE_CONF}'" > "$FILE_LOCAL_CONF"; then
        ERROR "Fetch failed from '${device}'."
        return 1
    fi

    OK "Fetched '${FILE_REMOTE_CONF}' from '${device}' → ${FILE_LOCAL_CONF}"
}

# ==============================================================================
# --- action_push ---
# @desc_short  : Pushes local config.conf to OBSERVER_PRIMARY as homelab.conf.
# @notes       : Observer distributes further to all devices via systemd path unit.
#                No device argument — target is always OBSERVER_PRIMARY.
# ==============================================================================
function action_push {
    # Local file must exist before pushing — cannot push an empty config.
    if [[ ! -f "$FILE_LOCAL_CONF" ]]; then
        ERROR "Local config not found: ${FILE_LOCAL_CONF}"
        INFO "Run --fetch or --edit first."
        return 1
    fi

    # Push to observer_1 only — observer distributes further automatically.
    _push_to_device "$OBSERVER_PRIMARY"
}

# --- _push_to_device ---
# @desc_short  : Pushes local config.conf to a single device as homelab.conf.
# @parameter   : $1 | device | Device name (host or observer)
# ==============================================================================
function _push_to_device {
    local device="$1"
    local ip user

    # Resolve device connection details from config arrays.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    INFO "Pushing config.conf → '${device}':${FILE_REMOTE_CONF}..."

    # Pipe local file content to remote destination via sudo (required for /opt/ paths).
    if ! ssh ${SSH_OPTS} "${user}@${ip}" \
            "sudo tee '${FILE_REMOTE_CONF}' > /dev/null" < "$FILE_LOCAL_CONF"; then
        ERROR "Push failed to '${device}'."
        return 1
    fi

    OK "Pushed config.conf → '${device}':${FILE_REMOTE_CONF}"
}
