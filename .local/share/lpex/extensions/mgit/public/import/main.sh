#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit public import' — Takes over an existing server repository.
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared import action of this area.
# ==============================================================================
function extension_start {
    # The area is the submodule above this action (public | private)
    local area="${PATH_EXTENSION_ARRAY[1]}"

    mgit_action_import "$area" "${ARG_REPO:-}" "${ARG_PATH:-}" "${ARG_BRANCH:-}"
}
