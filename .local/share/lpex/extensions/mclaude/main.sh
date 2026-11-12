#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'claude' — routes to the session and service actions.
# ==============================================================================

# source action files — must be explicit, LPEX does not auto-load _*.sh
# always via $PATH_EXTENSION (official LPEX variable) — never BASH_SOURCE/dirname
source "${PATH_EXTENSION}/_session.sh"
source "${PATH_EXTENSION}/_service.sh"

# --- extension_start ---
# @desc_short  : Validates the modifiers and routes the action.
# ==============================================================================
function extension_start {
    local action="${ARG_ACTION:-attach}"

    # Modifiers only make sense with their own action — say so instead of ignoring
    if (( ${ARG_READ_ONLY:-0} )) && [[ "$action" != "attach" ]]; then
        ERROR "--read-only only works with attach."; return 64
    fi
    if (( ${ARG_FOLLOW:-0} )) && [[ "$action" != "logs" ]]; then
        ERROR "--follow only works with logs."; return 64
    fi

    # Route by the first position
    case "$action" in
        attach)  _claude_action_attach ;;
        shell)   _claude_action_shell ;;
        status)  _claude_action_status ;;
        logs)    _claude_action_logs ;;
        restart) _claude_action_restart ;;
        update)  _claude_action_update ;;
        *)       ERROR "Unknown action: ${action} (attach|shell|status|logs|restart|update)"; return 64 ;;
    esac
}
