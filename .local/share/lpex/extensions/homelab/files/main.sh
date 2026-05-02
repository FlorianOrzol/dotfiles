#!/bin/bash
# ==============================================================================
# @meta_name        : files/main.sh
# @desc_short       : Router für Dateiübertragungen zum/vom Gerät-Mirror.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/transfer.sh"

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Entry point called by the LPEX framework.
# ==============================================================================
function extension_start {
    # 1. --- Validate Device Selection ---------------
    validate_device || return 1
    local device_type="$_DEVICE_TYPE"
    local device_id="$_DEVICE_ID"

    # 2. --- Validate Action Selection ---------------
    if [[ -z "$ARG_GOTO" && -z "$ARG_FETCH" && -z "$ARG_PUSH" && -z "$ARG_DELETE" ]]; then
        ERROR "No action specified. Provide --goto, --fetch, --push, or --delete."
        return 1
    fi

    # 3. --- Resolve Mirror Path ---------------
    # Mirror uses the logical device name, not numeric id (e.g. observer_1)
    local dev_name
    dev_name=$(device_name "$device_type" "$device_id")
    local mirror_path="${PATH_HOMELAB_DATA}/mirror/${device_type}/${dev_name}"

    # 4. --- Action Routing ---------------
    if [[ -n "$ARG_GOTO" ]];   then action_goto   "$mirror_path";                               fi
    if [[ -n "$ARG_FETCH" ]];  then action_fetch  "$device_type" "$device_id" "$mirror_path";   fi
    if [[ -n "$ARG_PUSH" ]];   then action_push   "$device_type" "$device_id" "$mirror_path";   fi
    if [[ -n "$ARG_DELETE" ]]; then action_delete "$device_type" "$device_id" "$mirror_path";   fi
}

# ==============================================================================
# --- function action_goto ---
# @desc_short       : Opens the local mirror directory in the terminal.
# @parameter        : $1 | mirror_path | Local mirror path for the device.
# ==============================================================================
function action_goto {
    local mirror_path="$1"

    if [[ ! -d "$mirror_path" ]]; then
        WARN "Mirror-Verzeichnis existiert noch nicht: $mirror_path"
        WARN "Erst --fetch ausführen, um es zu befüllen."
        return 1
    fi

    INFO "Öffne Mirror-Verzeichnis: $mirror_path"
    $TERMINAL "$mirror_path" &
}
