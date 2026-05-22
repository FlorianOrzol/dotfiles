#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'control/observer'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for observer power control and maintenance.
# @usage       : lpex homelab control observer --observer <name> <action>
# @notes       : Start is not supported remotely — use physical power or WOL manually.
# ==============================================================================
function arguments {
    arg_value @observer   --description "Target observer"                               --fzf --option-cmd "get_observers"
    arg_flag  @restart    --description "Restart the observer"
    arg_flag  @maintenance --description "Enable maintenance mode (promotes standby observer)"
    arg_flag  @activate   --description "Disable maintenance mode and restore normal operation"
}
