#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for the files submodule.
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments.
# @usage            : lpex homelab files <action> [path] [options]
#
# @actions          : --goto | --fetch | --push | --delete | --rename
# @options          : --rename-to (only with --rename)
#
# @notes            : Device type and name are derived from the mirror path structure:
#                       mirror/<type>/<device>/remote/path — no device flag needed.
#                     --fetch: provide the full mirror path including the remote portion,
#                       even if it does not exist locally yet.
#                     --delete: only locally mirrored paths can be selected; remote-only
#                       files must be deleted via cmd ssh.
# ==============================================================================
function arguments {
    # 1. --- Actions --------------------------------------------------------

    # --goto: select an existing mirror base directory.
    # Covers depth-2 devices (host, observer) and depth-3 client devices (client/ct, client/vm).
    arg_value @goto \
        --description "Open device mirror directory in terminal" \
        --option-cmd "
            { find '${PATH_EXTENSION_DATA}/mirror' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | grep -v '/client$';
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null; } \
            | sort"

    # --fetch: provide the full mirror path including the remote portion.
    # Covers depth-2 devices (host, observer) and depth-3 client devices (client/ct, client/vm).
    arg_value @fetch \
        --description "Fetch remote path into local mirror (full mirror path)" \
        --option-cmd "
            { find '${PATH_EXTENSION_DATA}/mirror' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | grep -v '/client$';
              find '${PATH_EXTENSION_DATA}/mirror/client' -mindepth 2 -maxdepth 2 -type d 2>/dev/null; } \
            | sort"

    # --push: takes a device name — mirror path is assembled internally from type + name.
    # Completion format: host_1, observer_1, ct_3040, vm_101 (type prefix for clients).
    # --multi allows pushing several devices at once.
    arg_value @push --multi \
        --description "Push whole device mirror to device (by device name)" \
        --option-cmd "
            { find '${PATH_EXTENSION_DATA}/mirror' -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
                | grep -v '/client$' \
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
                    echo \"\${subtype}_\${name}\"  # ct_3040, vm_101
                  done; } \
            | sort"

    # --delete: select one or more existing local mirror paths.
    # --multi allows deleting several paths in one call.
    arg_value @delete --multi \
        --description "Delete path on device and in local mirror" \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 3 2>/dev/null"

    # --rename: select a single existing local mirror path.
    arg_value @rename \
        --description "Rename file/directory on device and in mirror" \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 3 2>/dev/null"

    # 2. --- Options --------------------------------------------------------

    # --rename-to is only valid in combination with --rename.
    arg_value @rename-to \
        --description "New name for the renamed entry" \
        --depends-on "ARG_RENAME"
}
