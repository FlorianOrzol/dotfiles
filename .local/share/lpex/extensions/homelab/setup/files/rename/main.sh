#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Renames a file or directory on the device and in the local mirror.
#                     Remote rename must succeed before the local mirror is touched.
# ==============================================================================

source "${PATH_EXTENSION_SOURCE}/homelab/setup/files/_common.sh"
source "${PATH_EXTENSION_SOURCE}/homelab/setup/files/_rename.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates arguments and delegates to the shared rename logic.
#                ARG_RENAME_TO is read directly by action_rename from the global scope.
# ==============================================================================
function extension_start {
    # Both source path and new name are required.
    [[ -z "$ARG_PATH"      ]] && { ERROR "No path specified."; return 1; }
    [[ -z "$ARG_RENAME_TO" ]] && { ERROR "No new name specified. Use --rename-to <name>."; return 1; }

    # Delegate to shared rename logic — action_rename reads ARG_RENAME_TO directly.
    action_rename "$ARG_PATH"
}
