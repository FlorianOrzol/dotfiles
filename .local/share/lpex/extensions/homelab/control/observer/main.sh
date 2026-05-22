#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates and routes power and maintenance actions for observers.
# ==============================================================================

source "${PATH_EXTENSION}/_power.sh"
source "${PATH_EXTENSION}/_maintenance.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates arguments and dispatches to the appropriate action.
# @notes       : Start is not supported remotely — only restart, maintenance, activate.
# ==============================================================================
function extension_start {
    [[ -z "$ARG_OBSERVER" ]] && { ERROR "No observer specified. Use --observer <name>."; return 1; }  # device required

    [[ -n "$ARG_MAINTENANCE" && -n "$ARG_ACTIVATE" ]] && { ERROR "--maintenance and --activate are mutually exclusive."; return 1; }

    if [[ -z "$ARG_RESTART" && -z "$ARG_MAINTENANCE" && -z "$ARG_ACTIVATE" ]]; then
        ERROR "No action specified. Use --restart, --maintenance, or --activate."
        return 1
    fi

    [[ -n "$ARG_MAINTENANCE" ]] && { action_maintenance "$ARG_OBSERVER" || return 1; }   # state change before power
    [[ -n "$ARG_ACTIVATE" ]]    && { action_activate    "$ARG_OBSERVER" || return 1; }
    [[ -n "$ARG_RESTART" ]]     && action_power "$ARG_OBSERVER" "restart"
}
