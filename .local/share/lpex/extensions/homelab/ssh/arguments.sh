#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the ssh submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab ssh <device>
#
# @devices          : --host | --observer | --container | --vm
#
# @notes            : Exactly one device must be specified — SSH opens a single
#                     interactive session. No --fzf, no --multi.
#                     Hosts and VMs are reached via ProxyJump through OBSERVER_PRIMARY.
#                     Containers are entered via pct enter on their host.
# ==============================================================================
function arguments {
    # Device selection — tab completion from live device lists, no forced fzf dialog.
    arg_value @host      --description "SSH into a host (via observer proxy)"     --option-cmd "get_hosts"
    arg_value @observer  --description "SSH into an observer (direct connection)"  --option-cmd "get_observers"
    arg_value @container --description "Enter a container shell (pct enter)"       --option-cmd "get_containers"
    arg_value @vm        --description "SSH into a VM (via observer + host proxy)" --option-cmd "get_vms"
}
