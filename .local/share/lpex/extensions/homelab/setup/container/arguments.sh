#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'setup container'.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments for container lifecycle changes.
# @usage            : lpex homelab setup container <id> --delete
#
# @id               : <id>       → existing Proxmox VMID (arg_direct)
# @actions          : --delete   → stop (with confirmation), destroy, and clean up all traces
#
# @notes            : --create is planned for the same submodule, not built yet.
# ==============================================================================
function arguments {
    arg_direct @id     --description "Existing container ID"                     --fzf --option-cmd "get_containers"
    arg_flag   @delete --description "Delete the container: stop, destroy, clean up all traces"
}
