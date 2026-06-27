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

    local type _d _r
    parse_mirror_path "$ARG_PATH" type _d _r

    if _is_unified_mirror_type "$type"; then
        # Unified mirror — apply rename to every device of this type so all stay in sync.
        # Local mirror entry is renamed only on the last iteration (inside action_rename).
        local devices=() dev last_dev
        case "$type" in
            host)     devices=("${HOSTS[@]}") ;;
            observer) devices=("${OBSERVERS[@]}") ;;
        esac
        last_dev="${devices[-1]}"
        for dev in "${devices[@]}"; do
            if [[ "$dev" == "$last_dev" ]]; then
                action_rename "$ARG_PATH" "$dev" || return 1  # last device also renames local mirror
            else
                # Remote only — skip local rename until the last device to avoid renaming twice
                _rename_on_device "$type" "$dev" "$_r" "$(dirname "$_r")/${ARG_RENAME_TO}" || return 1
            fi
        done
    else
        # Per-device mirror — device is encoded in the path.
        action_rename "$ARG_PATH"
    fi
}
