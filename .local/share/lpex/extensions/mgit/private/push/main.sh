#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit private push' — Picks up new files, commits and uploads.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared push action of this area.
# ==============================================================================
function extension_start {
    # The area is the submodule above this action (public | private)
    local area="${PATH_EXTENSION_ARRAY[1]}"

    mgit_action_push "$area" "${ARG_REPO:-}" "${ARG_MESSAGE[*]:-}"
}
