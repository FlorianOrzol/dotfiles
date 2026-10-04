#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit private status' — Shows changed files and files the next push adds.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared status action of this area.
# ==============================================================================
function extension_start {
    # The area is the submodule above this action (public | private)
    local area="${PATH_EXTENSION_ARRAY[1]}"

    mgit_action_status "$area" "${ARG_REPO:-}"
}
