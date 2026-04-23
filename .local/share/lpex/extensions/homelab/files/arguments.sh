#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Defines the CLI arguments for the files submodule.
# ==============================================================================

# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers all arguments for local mirror file management.
# @usage            : lpex homelab files <device> <id> [options]
#
# @devices          : --host | --container | --vm | --observer
# @options          : --goto | --fetch | --push | --delete
# ==============================================================================
function arguments {
    # 1. --- Devices ---------------
    # ------ Mutually exclusive options for target selection.

    arg_value @host --description "Target host (ID from homelab_conf.db)" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @container --description "Target container (e.g., 1111)" \
        --option-cmd "cat '$FILE_CONTAINER_LIVE' 2>/dev/null"

    arg_value @vm --description "Target VM (e.g., 1111)" \
        --option-cmd "cat '$FILE_VM_LIVE' 2>/dev/null"

    arg_value @observer --description "Target Observer / Raspberry Pi (ID from homelab_conf.db)" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'observers' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    # 2. --- Options ---------------

    arg_flag @goto --description "Open local mirror directory in terminal"

    arg_value @fetch --description "Fetch file/directory from device into local mirror (remote path)"

    arg_value @push --description "Push local file/directory to device" --fzf \
        --option-cmd "find '$PATH_EXTENSION_DATA/mirror' -type f 2>/dev/null"

    arg_value @delete --description "Delete file/directory on device AND in local mirror" --fzf \
        --option-cmd "find '$PATH_EXTENSION_DATA/mirror' -type f 2>/dev/null"
}
