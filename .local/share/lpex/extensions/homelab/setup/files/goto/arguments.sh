#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the goto submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : homelab setup files goto <local_mirror_dir>
#
# @positional       : <dir> | Local mirror base directory to open in terminal
# ==============================================================================
function arguments {
    # Mirror directory as positional arg — FZF lists all known device mirror roots.
    # Covers depth-2 devices (host, observer) and depth-3 client devices (client/ct, client/vm).
    arg_direct @dir \
        --description "Device mirror directory to open" \
        --fzf \
        --option-cmd "
            { find '${PATH_EXTENSION_DATA}/mirror' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | grep -v '/client\$';
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null; } \
            | sort"
}
