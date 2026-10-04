#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit private git' — Runs a raw git command against a repository.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared git action of this area.
# ==============================================================================
function extension_start {
    # The area is the submodule above this action (public | private)
    local area="${PATH_EXTENSION_ARRAY[1]}"

    mgit_action_git "$area" "$ARG_REPO" "${ARG_GIT[@]}"
}
