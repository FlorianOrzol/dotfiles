#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the push submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : homelab setup files push <device>
#
# @positional       : <device> | Device name (host_1, observer_1, ct_3040, vm_101)
# ==============================================================================
function arguments {
    # Device as positional arg — FZF lists all devices with a known mirror directory.
    arg_direct @device \
        --description "Target device (e.g. host_1, ct_3040)" \
        --fzf \
        --option-cmd "
            { find '${PATH_EXTENSION_DATA}/mirror' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | grep -v '/client\$' \
                | while IFS= read -r d; do
                    type=\$(basename \"\$(dirname \"\$d\")\")
                    name=\$(basename \"\$d\")
                    case \"\$type\" in
                        host|observer) echo \"\$name\" ;;
                        container)     echo \"container_\$name\" ;;
                        vm)            echo \"vm_\$name\" ;;
                    esac
                  done;
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | while IFS= read -r d; do
                    subtype=\$(basename \"\$(dirname \"\$d\")\")
                    name=\$(basename \"\$d\")
                    echo \"\${subtype}_\${name}\"
                  done; } \
            | sort"
}
