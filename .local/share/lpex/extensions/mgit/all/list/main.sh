#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit all list' — Shows repositories, remotes and tracked paths.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Runs the shared list action for every area.
# ==============================================================================
function extension_start {
    local area

    # public first, then private — same order as 'all list'
    for area in "${MGIT_AREAS[@]}"; do
        mgit_action_list "$area" "" "${ARG_FILES:-0}"
    done
}
