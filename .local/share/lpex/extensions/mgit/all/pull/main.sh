#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit all pull' — Fetches remote changes; clones missing repositories.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Runs the shared pull action for every area.
# ==============================================================================
function extension_start {
    local area
    local count_failed=0

    # public first, then private — a failing area does not stop the other
    for area in "${MGIT_AREAS[@]}"; do
        mgit_action_pull "$area" "" || (( count_failed++ ))
    done

    # Non-zero when at least one area failed
    (( count_failed == 0 ))
}
