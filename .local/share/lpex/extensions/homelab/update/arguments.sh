#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the update submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab update [devices] [options]
#
# @devices          : --host | --observer | --container | --vm  (each repeatable via --multi)
# @options          : --dry-run | --patches
#
# @notes            : At least one device must be specified. Multiple devices of the
#                     same or different type can be freely combined.
# ==============================================================================
function arguments {
    # 1. --- Device Selection -----------------------------------------------
    # --multi allows selecting or specifying several devices of the same type at once.
    # No --fzf — the value is not entered interactively but chosen from completion.
    arg_value @host      --description "Host(s) to update"      --multi --option-cmd "get_hosts"
    arg_value @observer  --description "Observer(s) to update"  --multi --option-cmd "get_observers"
    arg_value @container --description "Container(s) to update" --multi --option-cmd "get_containers"
    arg_value @vm        --description "VM(s) to update"        --multi --option-cmd "get_vms"

    # 2. --- Modifiers -------------------------------------------------------
    # Modifiers apply to all selected devices.
    arg_flag @dry-run --description "Show upgradable packages only — no actual update"
    arg_flag @patches --description "Apply pending patches after OS update"
}
