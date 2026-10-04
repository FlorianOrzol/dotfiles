#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit private list' — Shows repositories, remotes and tracked paths.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared list action of this area.
# ==============================================================================
function extension_start {
    # The area is the submodule above this action (public | private)
    local area="${PATH_EXTENSION_ARRAY[1]}"

    mgit_action_list "$area" "${ARG_REPO:-}" "${ARG_FILES:-0}"
}
