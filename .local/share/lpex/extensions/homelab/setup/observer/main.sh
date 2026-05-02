#!/bin/bash
# ==============================================================================
# @meta_name        : setup/observer/main.sh
# @desc_short       : Router für Observer-Setup-Aktionen.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/_init.sh"

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Validates ID and action, then routes.
# ==============================================================================
function extension_start {
    # 1. --- Validate ID ---------------
    if [[ -z "$ARG_OBSERVER" ]]; then
        ERROR "Keine Observer-ID angegeben."
        return 1
    fi

    # 2. --- Validate Action ---------------
    if [[ -z "$ARG_INIT" ]]; then
        ERROR "Keine Aktion angegeben. Verwende --init."
        return 1
    fi

    # 3. --- Resolve logical name and force flag ---------------
    local obs_name force=0
    obs_name=$(_device_name "observer" "$ARG_OBSERVER")
    [[ -n "$ARG_FORCE" ]] && force=1

    # 4. --- Action Routing ---------------
    if [[ -n "$ARG_INIT" ]]; then
        _action_init "$ARG_OBSERVER" "$obs_name" "$force"
    fi
}
