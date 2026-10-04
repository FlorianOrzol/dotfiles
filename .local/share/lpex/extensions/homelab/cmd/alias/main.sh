#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Runs a saved shortcut on its device(s).
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Resolves the target devices and runs the stored command on each.
# ==============================================================================
function extension_start {
    local alias="$ARG_ALIAS"
    local -a devices_stored devices_target devices_failed
    local device

    # Alias is required — fzf already offered the list
    if [[ -z "$alias" ]]; then
        ERROR "No alias specified."
        return 1
    fi

    # Loads CMD_CMD and CMD_DEVICES
    cmd_read_alias "$alias" || return 1

    # Devices are stored space-separated — split into an array
    read -ra devices_stored <<< "$CMD_DEVICES"

    # --device narrows the run; without it every stored device is a target
    if (( ${#ARG_DEVICE[@]} > 0 )); then
        devices_target=("${ARG_DEVICE[@]}")
    else
        devices_target=("${devices_stored[@]}")
    fi

    # A shortcut only runs where it was saved for — anything else is a typo
    for device in "${devices_target[@]}"; do
        if [[ " ${devices_stored[*]} " != *" ${device} "* ]]; then
            ERROR "'${alias}' is not saved for '${device}' (saved for: ${CMD_DEVICES})."
            return 1
        fi
    done

    INFO "${alias}: ${CMD_CMD}"

    # Several devices at once deserve one look before anything runs
    if (( ${#devices_target[@]} > 1 )); then
        question "Run on ${devices_target[*]}?" || return 1
    fi

    # Run device by device and remember failures instead of stopping at the first
    for device in "${devices_target[@]}"; do
        execute_on_target "$device" "$CMD_CMD" || devices_failed+=("$device")
    done

    # Summary only matters when something went wrong
    if (( ${#devices_failed[@]} > 0 )); then
        ERROR "'${alias}' failed on: ${devices_failed[*]}"
        return 1
    fi

    OK "'${alias}' done on ${devices_target[*]}."
}
