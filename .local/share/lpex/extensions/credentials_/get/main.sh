#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: credentials get
# ==============================================================================

function extension_start() {
    _unlock_rbw
    command rbw get "${ARG_RBW_GET[@]}"
}
