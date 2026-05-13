#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the globals submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab setup globals <action> [device]
#
# @actions          : --edit | --fetch | --push
#
# @notes            : Manages the global homelab variable file (homelab.conf).
#                     Desktop path : ${PATH_EXTENSION_DATA}/config.conf
#                     Device path  : /opt/homelab/homelab.conf
#
#                     --edit   : Opens local config.conf in $EDITOR (no device needed).
#                     --fetch  : Pulls homelab.conf from a single device into local config.
#                     --push   : Pushes local config.conf to OBSERVER_PRIMARY only.
#                                Observer distributes further via systemd path unit.
#                                No device argument — target is always fixed.
# ==============================================================================
function arguments {
    # 1. --- Actions --------------------------------------------------------

    # --edit opens the local config.conf — no device selection required.
    arg_flag @edit \
        --description "Open local homelab.conf (config.conf) in \$EDITOR"

    # --fetch pulls from exactly one device — use option-cmd for completion.
    arg_value @fetch \
        --description "Fetch homelab.conf from a device into local config.conf" \
        --option-cmd "get_nodes"

    # --push always targets OBSERVER_PRIMARY — observer distributes further automatically.
    arg_flag @push \
        --description "Push local config.conf to OBSERVER_PRIMARY (observer distributes further)"
}
