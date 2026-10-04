#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd run'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for running a command once.
# @usage       : lpex homelab cmd run <device> --cmd <command> [--save <alias> [--description <text>]]
#
# @devices     : <device>      | host_N, observer_N, ct_<id>, vm_<id> (positional)
# @options     : --cmd         | Command to execute — prompted when missing
#                --save        | Also save the command as shortcut (only after success)
#                --description | Description for the saved shortcut (only with --save)
# ==============================================================================
function arguments {
    # Device as positional arg — nodes, live containers and VMs with their prefix
    arg_direct @device --description "Target device (host_1, observer_1, ct_3080, vm_101)" --fzf \
        --option-cmd "get_cmd_devices"

    # --multi collects unquoted words up to the next flag: --cmd df -h works too
    arg_value @cmd --description "Command to execute" --multi

    # Optional: keep the command as shortcut
    arg_value @save --description "Save as shortcut with this alias (only if the command succeeds)"
    arg_value @description --description "Description of the shortcut" --depends-on "ARG_SAVE"
}
