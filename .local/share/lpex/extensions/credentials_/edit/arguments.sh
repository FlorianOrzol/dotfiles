#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: credentials edit
# ==============================================================================

function arguments() {
    if _is_initialized; then
        _unlock_rbw
        arg_wrap "rbw edit"
    else
        output --warn "Credentials not initialized. Please run 'lpex credentials init' first."
    fi
}
