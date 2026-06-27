#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the rename submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : homelab setup files rename <local_mirror_path> --rename-to <new_name>
#
# @positional       : <path>       | Full local mirror path of the entry to rename
# @options          : --rename-to  | New filename (basename only, not a full path)
# ==============================================================================
function arguments {
    # Path as positional arg — FZF lists all existing local mirror entries.
    arg_direct @path \
        --description "Local mirror path to rename (on device and in mirror)" \
        --fzf \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 3 2>/dev/null | sort"

    # New name is required — only shown after path is selected.
    arg_value @rename-to \
        --description "New name for the entry" \
        --depends-on "ARG_PATH"
}
