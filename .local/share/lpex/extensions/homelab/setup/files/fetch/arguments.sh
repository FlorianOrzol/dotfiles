#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the fetch submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : homelab setup files fetch --device <device> --path <dir>
#
# @options          : --device  | Target device (host_1, observer_1, ct_3040, vm_101)
#                   : --path    | Base directory on the device to search (e.g. /root, /opt/homelab)
#
# @notes            : File selection via FZF happens in extension_start — SSH find results
#                   : are piped into FZF there, where all functions and variables are available.
#                   : --option-cmd subprocesses lack the exported helpers needed for SSH routing.
# ==============================================================================
function arguments {
    # Device selection — FZF lists all devices with a known mirror directory.
    arg_value @device \
        --description "Target device (e.g. host_1, ct_3040)" \
        --fzf \
        --option-cmd "
            { get_hosts    | awk '{print \$1}';
              get_observers | awk '{print \$1}';
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | while IFS= read -r d; do
                    subtype=\$(basename \"\$(dirname \"\$d\")\")
                    name=\$(basename \"\$d\")
                    echo \"\${subtype}_\${name}\"
                  done; } \
            | sort"

    # Base directory on the device — free text, no completion.
    # The recursive find + FZF file selection happens in extension_start.
    arg_value @path \
        --description "Base directory to search on device (e.g. /root or /opt/homelab)" \
        --depends-on "ARG_DEVICE"
}
