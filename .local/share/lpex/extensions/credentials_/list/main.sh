#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: credentials list
# ==============================================================================

function extension_start() {
    _unlock_rbw
    command rbw list "${ARG_RBW_LIST[@]}"
}
