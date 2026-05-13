#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd ssh'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for executing an ad-hoc SSH command.
# @usage       : lpex homelab cmd ssh "<command>" --device <device>
#
# @options     : <command>  | Shell command to execute remotely (required, positional)
#                --device   | Target device (required)
# ==============================================================================
function arguments {
    arg_direct @cmd    --description "Command to execute remotely"
    arg_value  @device --description "Target device" --fzf \
                           --option-cmd "get_all_devices"
}
