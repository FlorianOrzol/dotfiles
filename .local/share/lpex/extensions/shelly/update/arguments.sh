#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'shelly update'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers the target and the check-only switch.
# @usage       : lpex shelly update <device|all> [--check] [--yes]
#
# @options     : <device> | id, MAC, IP — or 'all' (positional, fzf)
#                --check  | Only ask the devices for new firmware, install nothing
#                --yes    | Do not ask before installing
# @notes       : Installing restarts the device (~1 minute without function).
# ==============================================================================
function arguments {
    arg_direct @device --description "Device (id, MAC, IP) or all" --fzf \
        --option "all # every device in the inventory" --option-cmd "get_shelly_devices"
    arg_flag   @check  --description "Only check, install nothing"
    arg_flag   @yes    --description "Do not ask before installing"
}
