#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd edit'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for editing a saved shortcut.
# @usage       : lpex homelab cmd edit <alias> [--new-alias <name>] [--cmd <command>]
#                                      [--description <text>] [--add-device <device...>]
#                                      [--remove-device <device...>]
#
# @options     : <alias>         | Shortcut to edit (positional, fzf)
#                --new-alias     | Rename the shortcut
#                --cmd           | Replace the command
#                --description   | Replace the description
#                --add-device    | Add device(s)
#                --remove-device | Remove device(s) — at least one must remain
# @notes       : Without any option the whole entry opens in $EDITOR.
#                No --depends-on "ARG_ALIAS": the alias is positional, so '--alias'
#                never appears in the typed tokens and completion would hide all options.
# ==============================================================================
function arguments {
    local alias_selected

    arg_direct @alias --description "Shortcut to edit" --fzf --option-cmd "get_cmd_aliases"

    # ARG_ALIAS is not set during completion — the typed alias is the first token then.
    # A first token starting with -- is a flag (alias not typed yet), not an alias.
    alias_selected="${ARG_ALIAS:-${ARGS_ENTERED[0]}}"
    [[ "$alias_selected" == --* ]] && alias_selected=""

    arg_value @new_alias   --description "New alias name"
    arg_value @cmd         --description "New command" --multi
    arg_value @description --description "New description"

    # Adding offers every device, removing only the ones stored for this alias
    arg_value @add_device    --description "Add device(s)" --multi --option-cmd "get_cmd_devices"
    arg_value @remove_device --description "Remove device(s)" --multi \
        --option-cmd "get_cmd_alias_devices $(printf '%q' "$alias_selected")"
}
