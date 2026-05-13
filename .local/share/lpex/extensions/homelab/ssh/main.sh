#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates device selection and opens an interactive SSH session.
# ==============================================================================

source "${PATH_EXTENSION}/_connect.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Enforces exactly one device flag, then opens the SSH session.
# ==============================================================================
function extension_start {
    local device_count=0

    # Count how many device flags were provided.
    [[ -n "$ARG_HOST" ]]      && (( device_count++ ))
    [[ -n "$ARG_OBSERVER" ]]  && (( device_count++ ))
    [[ -n "$ARG_CONTAINER" ]] && (( device_count++ ))
    [[ -n "$ARG_VM" ]]        && (( device_count++ ))

    # Require exactly one device — no device means nothing to connect to.
    if (( device_count == 0 )); then
        ERROR "No device specified. Use --host, --observer, --container, or --vm."
        return 1
    fi

    # More than one device is ambiguous — SSH opens one interactive session at a time.
    if (( device_count > 1 )); then
        ERROR "Only one device can be targeted at a time."
        return 1
    fi

    # Route to the appropriate connection function based on which flag was set.
    [[ -n "$ARG_OBSERVER" ]]  && { ssh_observer  "$ARG_OBSERVER";  return $?; }
    [[ -n "$ARG_HOST" ]]      && { ssh_host      "$ARG_HOST";      return $?; }
    [[ -n "$ARG_CONTAINER" ]] && { ssh_container "$ARG_CONTAINER"; return $?; }
    [[ -n "$ARG_VM" ]]        && { ssh_vm        "$ARG_VM";        return $?; }
}
