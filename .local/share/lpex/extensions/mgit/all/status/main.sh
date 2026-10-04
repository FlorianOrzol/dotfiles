#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit all status' — Shows changed files and files the next push adds.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Runs the shared status action for every area.
# ==============================================================================
function extension_start {
    local area

    # public first, then private — same order as 'all list'
    for area in "${MGIT_AREAS[@]}"; do
        mgit_action_status "$area" ""
    done
}
