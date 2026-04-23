#!/bin/bash
# ==============================================================================
# @meta_name        : extension_global.sh
# @desc_short       : Shared helper functions for all homelab submodules.
#                     Sourced automatically by LPEX before arguments() runs.
# ==============================================================================

# ==============================================================================
# --- function _validate_device ---
# @desc_short       : Ensures exactly one target device is selected.
#                     Sets globals _DEVICE_TYPE and _DEVICE_ID on success.
# @usage            : _validate_device || return 1
# ==============================================================================
function _validate_device {
    local count=0
    declare -g _DEVICE_TYPE=""
    declare -g _DEVICE_ID=""

    if [[ -n "$ARG_HOST" ]];      then (( count++ )); _DEVICE_TYPE="host";      _DEVICE_ID="$ARG_HOST";      fi
    if [[ -n "$ARG_OBSERVER" ]];  then (( count++ )); _DEVICE_TYPE="observer";  _DEVICE_ID="$ARG_OBSERVER";  fi
    if [[ -n "$ARG_CONTAINER" ]]; then (( count++ )); _DEVICE_TYPE="container"; _DEVICE_ID="$ARG_CONTAINER"; fi
    if [[ -n "$ARG_VM" ]];        then (( count++ )); _DEVICE_TYPE="vm";        _DEVICE_ID="$ARG_VM";        fi

    if (( count != 1 )); then
        ERROR "Exactly one target device required (--host, --observer, --container, or --vm)."
        return 1
    fi
}
