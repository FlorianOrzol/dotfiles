#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: credentials add
# Creates a new Bitwarden entry using piped input to bypass the editor.
# ==============================================================================

function extension_start() {
    # Ensure daemon is ready

    $EDITOR $FILE_PRIVATE_GLOBALS || output --error "Failed to open editor for private globals." || exit 1 



}
