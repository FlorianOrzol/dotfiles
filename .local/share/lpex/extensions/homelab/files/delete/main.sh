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
    # Mirror path is required — it encodes the device type and remote path.
    [[ -z "$ARG_PATH" ]] && { ERROR "No path specified."; return 1; }

    local type _d _r
    parse_mirror_path "$ARG_PATH" type _d _r

    if _is_unified_mirror_type "$type"; then
        # Unified mirror — apply deletion to every device of this type so all stay in sync.
        local devices=()
        case "$type" in
            host)     devices=("${HOSTS[@]}") ;;
            observer) devices=("${OBSERVERS[@]}") ;;
        esac
        for dev in "${devices[@]}"; do
            action_delete "$ARG_PATH" "$dev" || return 1
        done
    else
        # Per-device mirror — device is encoded in the path.
        action_delete "$ARG_PATH"
    fi
}
