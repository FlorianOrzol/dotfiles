#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'claude'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex claude [attach|shell|status|logs|restart|update] [options]
#
# @actions     : attach (default) | shell | status | logs | restart | update
# @options     : --read-only (only with attach) — watch without typing
#                --follow    (only with logs)   — journalctl -f
# ==============================================================================
function arguments {
    # Without an action the main session opens — the common case needs no word
    arg_direct @action --description "Action (default: attach)" --option-cmd "claude_actions"

    # Modifiers of single actions — checked against the action in main.sh
    arg_flag @read_only --description "attach: watch only, keystrokes are not sent"
    arg_flag @follow    --description "logs: keep following the journal"
}
