#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: credentials add
# Defines arguments for adding credentials without opening an editor.
# ==============================================================================

function arguments() {
    # No unlock required here. Setup and unlocking will be handled 
    # exclusively in the main execution logic (main.sh).

    # Item name (Username will be set to the same value as name)
    arg_value @name \
        --description "Name of the credential entry"

    # Value (Password or Note content)
    arg_value @value \
        --description "Value to store (password or notes)" \
        --depends-on "ARG_NAME"

    # Type of the entry
    arg_value @type \
        --description "Storage type" \
        --option "password # Store value as password (default)" \
        --option "ssh # Store value in notes (for keys)" \
        --option "notice # Store value in notes (for text)" \
        --depends-on "ARG_VALUE"
}
