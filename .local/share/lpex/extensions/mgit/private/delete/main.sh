#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit private delete' — Deletes a repository on the servers and locally.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared delete action of this area.
# ==============================================================================
function extension_start {
    # The area is the submodule above this action (public | private)
    local area="${PATH_EXTENSION_ARRAY[1]}"

    mgit_action_delete "$area" "${ARG_REPO:-}" "${ARG_LOCAL_ONLY:-0}"
}
