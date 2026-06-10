#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Opens a local mirror directory in the configured terminal.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates the mirror directory and opens it in the terminal.
# ==============================================================================
function extension_start {
    # Mirror directory is required.
    [[ -z "$ARG_DIR" ]] && { ERROR "No directory specified."; return 1; }

    # Directory must exist locally — run fetch first if not yet populated.
    if [[ ! -d "$ARG_DIR" ]]; then
        WARN "Mirror directory does not exist: ${ARG_DIR}"
        INFO "Run 'homelab setup files fetch' first to populate the mirror."
        return 1
    fi

    INFO "Opening mirror: ${ARG_DIR}"

    # Open in background so the terminal launch does not block the shell.
    $TERMINAL "$ARG_DIR" &
}
