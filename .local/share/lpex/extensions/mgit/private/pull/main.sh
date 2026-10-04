#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit private pull' — Fetches remote changes; clones missing repositories.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared pull action of this area.
# ==============================================================================
function extension_start {
    # The area is the submodule above this action (public | private)
    local area="${PATH_EXTENSION_ARRAY[1]}"

    mgit_action_pull "$area" "${ARG_REPO:-}"
}
