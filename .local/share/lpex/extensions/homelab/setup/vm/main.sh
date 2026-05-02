#!/bin/bash
# ==============================================================================
# @meta_name        : setup/vm/main.sh
# @desc_short       : Router für VM-Setup-Aktionen.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/_create.sh"
source "$(dirname "${BASH_SOURCE[0]}")/_delete.sh"
source "$(dirname "${BASH_SOURCE[0]}")/_edit.sh"

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Validates ID and action, then routes to the correct function.
# ==============================================================================
function extension_start {
    # 1. --- Validate ID ---------------
    if [[ -z "$ARG_ID" ]]; then
        ERROR "No VM ID specified."
        return 1
    fi

    # 2. --- Validate Action — exactly one required ---------------
    local action_count=0
    [[ -n "$ARG_CREATE" ]]      && (( action_count++ ))
    [[ -n "$ARG_DELETE" ]]      && (( action_count++ ))
    [[ -n "$ARG_EDIT" ]]        && (( action_count++ ))
    [[ -n "$ARG_SHOW_CONFIG" ]] && (( action_count++ ))

    if (( action_count == 0 )); then
        ERROR "No action specified. Provide --create, --delete, --edit, or --show-config."
        return 1
    fi

    if (( action_count > 1 )); then
        ERROR "Only one action allowed at a time."
        return 1
    fi

    # 3. --- Action Routing ---------------
    if [[ -n "$ARG_CREATE" ]];      then _action_create;      fi
    if [[ -n "$ARG_DELETE" ]];      then _action_delete;      fi
    if [[ -n "$ARG_EDIT" ]];        then _action_edit;        fi
    if [[ -n "$ARG_SHOW_CONFIG" ]]; then _action_show_config; fi
}
