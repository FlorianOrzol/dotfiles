#!/bin/bash
# ==============================================================================
# @meta_name        : control/main.sh
# @desc_short       : Validates and routes power and HA-override actions.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/_power.sh"
source "$(dirname "${BASH_SOURCE[0]}")/_ha_override.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short   : Entry point — validates device + action, then dispatches.
# ==============================================================================
function extension_start {
    _validate_device || return 1
    local type="$_DEVICE_TYPE" id="$_DEVICE_ID"

    # Count power actions — only one allowed at a time
    local power_count=0
    [[ -n "$ARG_START" ]]   && (( power_count++ ))
    [[ -n "$ARG_STOP" ]]    && (( power_count++ ))
    [[ -n "$ARG_RESTART" ]] && (( power_count++ ))

    local ha_active=0
    [[ -n "$ARG_MAINTENANCE" || -n "$ARG_ACTIVATE" ]] && ha_active=1

    # Require at least one action
    if (( power_count == 0 && !ha_active )); then
        ERROR "No action specified. Provide --start, --stop, --restart, --maintenance, or --activate."
        return 1
    fi

    # Prevent combining multiple power actions
    if (( power_count > 1 )); then
        ERROR "Only one power action allowed at a time (--start, --stop, or --restart)."
        return 1
    fi

    # Prevent combining --maintenance and --activate
    if [[ -n "$ARG_MAINTENANCE" && -n "$ARG_ACTIVATE" ]]; then
        ERROR "--maintenance and --activate are mutually exclusive."
        return 1
    fi

    # Apply HA override first if requested, then execute power action
    if (( ha_active )); then
        _action_ha_override "$type" "$id" || return 1
    fi

    if [[ -n "$ARG_START" ]];   then _action_power "$type" "$id" "start";   fi
    if [[ -n "$ARG_STOP" ]];    then _action_power "$type" "$id" "stop";    fi
    if [[ -n "$ARG_RESTART" ]]; then _action_power "$type" "$id" "restart"; fi
}
