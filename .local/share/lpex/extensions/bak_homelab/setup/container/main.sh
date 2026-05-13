#!/bin/bash
# ==============================================================================
# @meta_name        : setup/container/main.sh
# @desc_short       : Router für Container-Setup-Aktionen.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/create.sh"
source "$(dirname "${BASH_SOURCE[0]}")/delete.sh"
source "$(dirname "${BASH_SOURCE[0]}")/edit.sh"
source "$(dirname "${BASH_SOURCE[0]}")/conf_push.sh"

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Validates ID and action, then routes to the correct function.
# ==============================================================================
function extension_start {
    # Container VMID is always required
    if [[ -z "$ARG_ID" ]]; then
        ERROR "No container ID specified."
        return 1
    fi

    # Count how many mutually exclusive actions were provided
    local action_count=0
    [[ -n "$ARG_CREATE" ]]      && (( action_count++ ))
    [[ -n "$ARG_DELETE" ]]      && (( action_count++ ))
    [[ -n "$ARG_EDIT" ]]        && (( action_count++ ))
    [[ -n "$ARG_SHOW_CONFIG" ]] && (( action_count++ ))
    [[ -n "$ARG_CONF_PUSH" ]]   && (( action_count++ ))

    # At least one action must be provided
    if (( action_count == 0 )); then
        ERROR "No action specified. Provide --create, --delete, --edit, --show-config, or --conf-push."
        return 1
    fi

    # Only one action may be requested at a time
    if (( action_count > 1 )); then
        ERROR "Only one action allowed at a time."
        return 1
    fi

    # Dispatch to the matching action function
    if [[ -n "$ARG_CREATE" ]];      then action_create;      fi
    if [[ -n "$ARG_DELETE" ]];      then action_delete;      fi
    if [[ -n "$ARG_EDIT" ]];        then action_edit;        fi
    if [[ -n "$ARG_SHOW_CONFIG" ]]; then action_show_config; fi
    if [[ -n "$ARG_CONF_PUSH" ]];   then action_conf_push;   fi
}
