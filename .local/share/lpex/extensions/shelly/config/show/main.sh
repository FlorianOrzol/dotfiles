#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Prints all settings of a device as "path = value".
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Loads the device and prints its flattened configuration.
# ==============================================================================
function extension_start {
    local config

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # Loads DEV_* from the inventory; protected devices need the password first
    shelly_resolve "$ARG_DEVICE" || return 1
    (( DEV_AUTH )) && { shelly_password || return 1; }

    if ! config=$(shelly_config_flat "$DEV_IP" "$DEV_GEN"); then
        ERROR "${DEV_ID}: no answer from ${DEV_IP}."
        return 1
    fi

    lx output --section "${DEV_ID} — settings (Gen${DEV_GEN})"

    # Filter case-insensitive — paths mix mqtt/MQTT between generations
    if [[ -n "$ARG_FILTER" ]]; then
        grep -i -E -- "$ARG_FILTER" <<< "$config" || INFO "No setting matches '${ARG_FILTER}'."
    else
        printf '%s\n' "$config"
    fi
}
