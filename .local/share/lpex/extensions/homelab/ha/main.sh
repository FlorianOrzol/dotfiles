#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates and routes HA list & boot order actions.
# ==============================================================================

# source shared helpers and action files — must be explicit, LPEX does not auto-load _*.sh
# always via $PATH_EXTENSION (official LPEX variable) — never BASH_SOURCE/dirname
source "${PATH_EXTENSION}/_common.sh"
source "${PATH_EXTENSION}/_list.sh"
source "${PATH_EXTENSION}/_modify.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates arguments and dispatches to the appropriate action.
# ==============================================================================
function extension_start {
    local action_count=0
    [[ -n "$ARG_ADD" ]]    && (( action_count++ ))   # count mutually exclusive actions
    [[ -n "$ARG_REMOVE" ]] && (( action_count++ ))
    [[ -n "$ARG_MOVE" ]]   && (( action_count++ ))
    [[ -n "$ARG_EDIT" ]]   && (( action_count++ ))
    (( action_count > 1 )) && { ERROR "Only one action at a time (--add, --remove, --move, --edit)."; return 1; }

    # --move without a target position is incomplete
    [[ -n "$ARG_MOVE" && -z "$ARG_TO" ]] && { ERROR "--move requires --to <position>."; return 1; }

    [[ -n "$ARG_ADD" ]]    && { action_add    "$ARG_ADD";            return $?; }
    [[ -n "$ARG_REMOVE" ]] && { action_remove "$ARG_REMOVE";         return $?; }
    [[ -n "$ARG_MOVE" ]]   && { action_move   "$ARG_MOVE" "$ARG_TO"; return $?; }
    [[ -n "$ARG_EDIT" ]]   && { action_edit;                         return $?; }

    action_list   # no action flag → default: show the boot order
}
