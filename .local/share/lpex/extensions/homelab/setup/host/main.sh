#!/bin/bash
# ==============================================================================
# @meta_name        : setup/host/main.sh
# @desc_short       : Router für Host-Setup-Aktionen.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/_init.sh"

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Validates ID and action, then routes.
# ==============================================================================
function extension_start {
    # 1. --- Validate ID ---------------
    if [[ -z "$ARG_HOST" ]]; then
        ERROR "Keine Host-ID angegeben."
        return 1
    fi

    # 2. --- Validate Action ---------------
    if [[ -z "$ARG_INIT" ]]; then
        ERROR "Keine Aktion angegeben. Verwende --init."
        return 1
    fi

    # 3. --- Resolve logical name and force flag ---------------
    local host_name force=0
    host_name=$(_device_name "host" "$ARG_HOST")
    [[ -n "$ARG_FORCE" ]] && force=1

    # 4. --- Action Routing ---------------
    if [[ -n "$ARG_INIT" ]]; then
        _action_init "$ARG_HOST" "$host_name" "$force"
    fi
}
