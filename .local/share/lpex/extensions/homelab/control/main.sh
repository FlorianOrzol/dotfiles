#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates and routes power and maintenance actions.
# ==============================================================================

source "${PATH_EXTENSION}/_power.sh"
source "${PATH_EXTENSION}/_maintenance.sh"

# ==============================================================================
# --- extension_start ---
# ==============================================================================
function extension_start {
    local type="" device=""

    # Determine device type from provided argument
    [[ -n "$ARG_HOST" ]]      && { type="host";      device="$ARG_HOST";      }
    [[ -n "$ARG_OBSERVER" ]]  && { type="observer";  device="$ARG_OBSERVER";  }
    [[ -n "$ARG_CONTAINER" ]] && { type="container"; device="$ARG_CONTAINER"; }
    [[ -n "$ARG_VM" ]]        && { type="vm";        device="$ARG_VM";        }

    # Count selected device types to enforce exactly one
    local device_count=0
    [[ -n "$ARG_HOST" ]]      && (( device_count++ ))
    [[ -n "$ARG_OBSERVER" ]]  && (( device_count++ ))
    [[ -n "$ARG_CONTAINER" ]] && (( device_count++ ))
    [[ -n "$ARG_VM" ]]        && (( device_count++ ))

    if (( device_count == 0 )); then
        ERROR "No device specified. Use --host, --observer, --container, or --vm."
        return 1
    fi

    if (( device_count > 1 )); then
        ERROR "Only one device can be targeted at a time."
        return 1
    fi

    # Count power actions to enforce exactly one
    local power_count=0
    [[ -n "$ARG_START" ]]   && (( power_count++ ))
    [[ -n "$ARG_STOP" ]]    && (( power_count++ ))
    [[ -n "$ARG_RESTART" ]] && (( power_count++ ))

    if (( power_count > 1 )); then
        ERROR "Only one power action allowed at a time (--start, --stop, --restart)."
        return 1
    fi

    # Maintenance and activate are mutually exclusive
    if [[ -n "$ARG_MAINTENANCE" && -n "$ARG_ACTIVATE" ]]; then
        ERROR "--maintenance and --activate are mutually exclusive."
        return 1
    fi

    # Require at least one action
    if (( power_count == 0 )) && [[ -z "$ARG_MAINTENANCE" && -z "$ARG_ACTIVATE" ]]; then
        ERROR "No action specified. Use --start, --stop, --restart, --maintenance, or --activate."
        return 1
    fi

    # Apply maintenance state change before power action
    [[ -n "$ARG_MAINTENANCE" ]] && { action_maintenance "$type" "$device" || return 1; }
    [[ -n "$ARG_ACTIVATE" ]]    && { action_activate    "$type" "$device" || return 1; }

    # Execute power action
    [[ -n "$ARG_START" ]]   && action_power "$type" "$device" "start"
    [[ -n "$ARG_STOP" ]]    && action_power "$type" "$device" "stop"
    [[ -n "$ARG_RESTART" ]] && action_power "$type" "$device" "restart"
}
