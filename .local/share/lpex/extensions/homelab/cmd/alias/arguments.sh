#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd alias'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for running a saved shortcut.
# @usage       : lpex homelab cmd alias <alias> [--device <device...>]
#
# @options     : <alias>    | Saved shortcut (positional, fzf)
#                --device   | Limit the run to some of its devices (default: all of them)
# ==============================================================================
function arguments {
    local alias_selected

    arg_direct @alias --description "Saved shortcut" --fzf --option-cmd "get_cmd_aliases"

    # ARG_ALIAS is not set during completion — the typed alias is the first token then.
    # A first token starting with -- is a flag (alias not typed yet), not an alias.
    alias_selected="${ARG_ALIAS:-${ARGS_ENTERED[0]}}"
    [[ "$alias_selected" == --* ]] && alias_selected=""

    # Offer only the devices stored for this alias; the value is baked into the
    # command string because --option-cmd runs in a subshell without ARG_*
    # No --depends-on "ARG_ALIAS": the alias is positional, '--alias' is never typed
    arg_value @device --description "Run only on these device(s)" --multi \
        --option-cmd "get_cmd_alias_devices $(printf '%q' "$alias_selected")"
}
