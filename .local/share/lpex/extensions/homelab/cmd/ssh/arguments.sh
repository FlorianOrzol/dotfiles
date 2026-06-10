#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'cmd ssh'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for executing an ad-hoc SSH command.
# @usage       : homelab cmd ssh <device> --cmd <command>
#
# @positional  : <device>  | Target device — hosts, observers, ct_<id>, vm_<id>
# @options     : --cmd     | Shell command to execute remotely (required)
# ==============================================================================
function arguments {
    # Device as positional arg — lists nodes from config and clients from mirror dirs.
    arg_direct @device \
        --description "Target device (e.g. host_1, observer_1, ct_3040, vm_101)" \
        --option-cmd "
            get_all_devices;
            { find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | while IFS= read -r d; do
                    subtype=\$(basename \"\$(dirname \"\$d\")\")
                    name=\$(basename \"\$d\")
                    echo \"\${subtype}_\${name}\"
                  done; } \
            | sort"

    arg_value @cmd --description "Command to execute remotely" --multi
}
