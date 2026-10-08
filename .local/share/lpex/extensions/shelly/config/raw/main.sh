#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Raw API call — for every setting without its own option.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Sends the request as given and prints the JSON answer.
# ==============================================================================
function extension_start {
    local answer

    # Device and request are required
    if [[ -z "$ARG_DEVICE" || -z "$ARG_REQUEST" ]]; then
        ERROR "Usage: lpex shelly config raw <device> <path|Method> [--params json]"
        return 1
    fi

    # Loads DEV_* from the inventory; protected devices need the password first
    shelly_resolve "$ARG_DEVICE" || return 1
    (( DEV_AUTH )) && { shelly_password || return 1; }

    # Gen2+: method + JSON parameters; Gen1: the path is the whole request
    if (( DEV_GEN >= 2 )); then
        # Parameters must be JSON — jq refuses anything else before it reaches the device
        if [[ -n "$ARG_PARAMS" ]] && ! jq -e . <<< "$ARG_PARAMS" >/dev/null 2>&1; then
            ERROR "--params is no valid JSON."
            return 1
        fi
        answer=$(shelly_rpc "$DEV_IP" "$ARG_REQUEST" "${ARG_PARAMS:-{\}}") || { ERROR "${DEV_ID}: RPC failed."; return 1; }
    else
        # Gen1 paths start with a slash
        if [[ "$ARG_REQUEST" != /* ]]; then
            ERROR "${DEV_ID} is Gen1 — the request is a path like /settings/relay/0?default_state=off"
            return 1
        fi
        answer=$(shelly_http "$DEV_IP" "$ARG_REQUEST" 1) || { ERROR "${DEV_ID}: request failed."; return 1; }
    fi

    # Pretty when JSON, verbatim otherwise
    jq . <<< "$answer" 2>/dev/null || printf '%s\n' "$answer"
}
