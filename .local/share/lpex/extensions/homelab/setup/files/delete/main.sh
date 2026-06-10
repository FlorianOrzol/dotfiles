#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Deletes a file or directory on the device and in the local mirror.
#                     Remote deletion must succeed before the local mirror is touched.
# ==============================================================================

source "${PATH_EXTENSION_SOURCE}/homelab/setup/files/_common.sh"
source "${PATH_EXTENSION_SOURCE}/homelab/setup/files/_delete.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates the path and delegates to the shared delete logic.
# ==============================================================================
function extension_start {
    # Mirror path is required — it encodes both the device and the remote path.
    [[ -z "$ARG_PATH" ]] && { ERROR "No path specified."; return 1; }

    # Delegate to shared delete logic which handles remote + local removal.
    action_delete "$ARG_PATH"
}
