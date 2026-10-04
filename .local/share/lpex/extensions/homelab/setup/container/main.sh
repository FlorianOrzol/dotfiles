#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Validates and routes container lifecycle changes.
# ==============================================================================

# source action file — must be explicit, LPEX does not auto-load _*.sh
# always via $PATH_EXTENSION (official LPEX variable) — never BASH_SOURCE/dirname
source "${PATH_EXTENSION}/_delete.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates arguments and dispatches to the appropriate action.
# ==============================================================================
function extension_start {
    [[ -z "$ARG_ID" ]] && { ERROR "No container ID specified."; return 1; }

    if [[ -n "$ARG_DELETE" ]]; then
        action_delete "$ARG_ID"
        return $?
    fi

    ERROR "No action specified. Use --delete. (--create is planned, not built yet.)"
    return 1
}
