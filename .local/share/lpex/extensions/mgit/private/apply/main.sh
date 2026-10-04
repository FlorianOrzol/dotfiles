#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'mgit private apply' — Installs root-owned files (e.g. sudoers).
# ==============================================================================

# --- extension_start ---
# @desc_short  : Hands over to the shared apply action.
# ==============================================================================
function extension_start {
    # System files only exist in the private area — no area parameter
    mgit_action_apply "${ARG_COLLECT:-0}"
}
