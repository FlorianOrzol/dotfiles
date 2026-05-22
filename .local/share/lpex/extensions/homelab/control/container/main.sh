#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates and routes power and maintenance actions for containers.
# ==============================================================================

source "${PATH_EXTENSION}/_power.sh"
source "${PATH_EXTENSION}/_maintenance.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates arguments and dispatches to the appropriate action.
# ==============================================================================
function extension_start {
    [[ -z "$ARG_CONTAINER" ]] && { ERROR "No container specified. Use --container <id>."; return 1; }  # device required

    local power_count=0
    [[ -n "$ARG_START" ]]   && (( power_count++ ))   # count mutually exclusive power actions
    [[ -n "$ARG_STOP" ]]    && (( power_count++ ))
    [[ -n "$ARG_RESTART" ]] && (( power_count++ ))
    (( power_count > 1 )) && { ERROR "Only one power action at a time (--start, --stop, --restart)."; return 1; }

    [[ -n "$ARG_MAINTENANCE" && -n "$ARG_ACTIVATE" ]] && { ERROR "--maintenance and --activate are mutually exclusive."; return 1; }

    if (( power_count == 0 )) && [[ -z "$ARG_MAINTENANCE" && -z "$ARG_ACTIVATE" ]]; then
        ERROR "No action specified. Use --start, --stop, --restart, --maintenance, or --activate."
        return 1
    fi

    [[ -n "$ARG_MAINTENANCE" ]] && { action_maintenance "$ARG_CONTAINER" || return 1; }   # state change before power
    [[ -n "$ARG_ACTIVATE" ]]    && { action_activate    "$ARG_CONTAINER" || return 1; }
    [[ -n "$ARG_START" ]]   && action_power "$ARG_CONTAINER" "start"
    [[ -n "$ARG_STOP" ]]    && action_power "$ARG_CONTAINER" "stop"
    [[ -n "$ARG_RESTART" ]] && action_power "$ARG_CONTAINER" "restart"
}
