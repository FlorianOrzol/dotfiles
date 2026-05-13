#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd alias'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for executing a saved command alias.
# @usage       : lpex homelab cmd alias <alias> [--device <device>]
#
# @options     : <alias>    | Alias name to execute (required, positional)
#                --device   | Target device override (optional, defaults to stored device(s))
# ==============================================================================
function arguments {
    arg_direct @alias  --description "Alias to execute" --fzf \
                           --option-cmd "get_cmd_aliases"
    arg_value  @device --description "Target device" --fzf \
                           --depends-on "ARG_ALIAS" \
                           --option-cmd "get_cmd_current_devices"
}
