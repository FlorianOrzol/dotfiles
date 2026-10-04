#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit private rm' — Stops tracking a path; files stay on disk.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared rm action of this area.
# ==============================================================================
function extension_start {
    # The area is the submodule above this action (public | private)
    local area="${PATH_EXTENSION_ARRAY[1]}"

    mgit_action_rm "$area" "$ARG_REPO" "${ARG_PATH:-}"
}
