#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: credentials list
# ==============================================================================

function arguments() {
    # Check if initialized to prevent hangs during typing
    if _is_initialized; then
        _unlock_rbw
        arg_wrap "rbw list"
    else
        output --warn "Credentials not initialized. Please run 'lpex credentials init' first."
    fi
}
