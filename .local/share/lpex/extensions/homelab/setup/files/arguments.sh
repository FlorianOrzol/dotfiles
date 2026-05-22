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

    # --goto: select an existing mirror base directory (mirror/<type>/<device>).
    # No --fzf — selection from completion list is sufficient.
    arg_value @goto \
        --description "Open device mirror directory in terminal" \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 2 -maxdepth 2 -type d 2>/dev/null"

    # --fetch: provide the full mirror path including the remote portion.
    # The mirror root is offered as starting point; the user types the remote path continuation.
    # --fzf is used because the user must actively enter the path (may not exist locally yet).
    arg_value @fetch \
        --description "Fetch remote path into local mirror (full mirror path)" \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 2 -maxdepth 2 -type d 2>/dev/null"

    # --push: select one or more existing local mirror paths.
    # --multi allows pushing several files/directories at once.
    arg_value @push --multi \
        --description "Push local mirror file/directory to device" \
        --option-cmd "find '${PATH_EXTENSION_DATA}/mirror' -mindepth 3 2>/dev/null"

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
