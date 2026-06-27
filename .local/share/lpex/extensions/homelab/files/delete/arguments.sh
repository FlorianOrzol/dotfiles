#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the delete submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : homelab setup files delete <local_mirror_path>
#
# @positional       : <path> | Full local mirror path of the entry to delete
# @notes            : Only locally mirrored paths can be selected — remote-only
#                     files must be deleted via cmd ssh.
# ==============================================================================
function arguments {
    # Path as positional arg — FZF lists all existing local mirror entries.
    arg_direct @path \
        --description "Local mirror path to delete (on device and in mirror)" \
        --fzf \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 3 2>/dev/null | sort"
}
