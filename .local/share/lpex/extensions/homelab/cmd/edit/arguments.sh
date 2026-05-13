#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd edit'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for editing a saved command entry.
# @usage       : lpex homelab cmd edit --alias <name> [--new-alias <name>] [--cmd <command>]
#                                      [--description <text>] [--add-device <device(s)>]
#                                      [--remove-device <device(s)>]
#
# @options     : --alias         | Alias of the entry to edit (required)
#                --new-alias     | Rename the alias (optional, pre-filled with current value)
#                --cmd           | Replace the command (optional, pre-filled with current value)
#                --description   | Replace the description (optional, pre-filled with current value)
#                --add-device    | Add one or more devices (optional, multi-select)
#                --remove-device | Remove one or more devices (optional, multi-select)
# ==============================================================================
function arguments {
    arg_value @alias         --description "Alias of the command to edit" --fzf \
                                 --option-cmd "get_cmd_aliases"
    arg_value @new_alias     --description "New alias name" \
                                 --depends-on "ARG_ALIAS" \
                                 --option-cmd "get_cmd_current_alias"
    arg_value @cmd           --description "New command" \
                                 --depends-on "ARG_ALIAS" \
                                 --option-cmd "get_cmd_current_cmd"
    arg_value @description   --description "New description" \
                                 --depends-on "ARG_ALIAS" \
                                 --option-cmd "get_cmd_current_description"
    arg_value @add_device    --description "Add device(s)" --multi \
                                 --depends-on "ARG_ALIAS" \
                                 --option-cmd "get_all_devices"
    arg_value @remove_device --description "Remove device(s)" --multi \
                                 --depends-on "ARG_ALIAS" \
                                 --option-cmd "get_cmd_current_devices"
}
