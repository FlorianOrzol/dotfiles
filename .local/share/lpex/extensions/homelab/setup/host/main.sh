#!/bin/bash
# ==============================================================================
# @meta_name        : setup/host/main.sh
# @desc_short       : Router für Host-Setup-Aktionen.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/init.sh"

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Validates ID and action, then routes.
# ==============================================================================
function extension_start {
    # Host ID is always required
    if [[ -z "$ARG_HOST" ]]; then
        ERROR "Keine Host-ID angegeben."
        return 1
    fi

    # At least one action must be specified
    if [[ -z "$ARG_INIT" ]]; then
        ERROR "Keine Aktion angegeben. Verwende --init."
        return 1
    fi

    local host_name force=0
    # Resolve the logical name for this host ID (e.g. "host_1")
    host_name=$(device_name "host" "$ARG_HOST")
    # Set force flag if --force was provided
    [[ -n "$ARG_FORCE" ]] && force=1

    # Route to init action
    if [[ -n "$ARG_INIT" ]]; then
        action_init "$ARG_HOST" "$host_name" "$force"
    fi
}
