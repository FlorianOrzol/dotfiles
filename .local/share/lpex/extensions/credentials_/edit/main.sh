#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: credentials edit
# ==============================================================================

function extension_start() {
    _unlock_rbw
    command rbw edit "${ARG_RBW_EDIT[@]}"
}
