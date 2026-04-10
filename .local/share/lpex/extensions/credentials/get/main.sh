#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: credentials get
# ==============================================================================

function extension_start() {
	cat "$FILE_PRIVATE_GLOBALS" | grep "^$ARG_VARIABLE" | awk -F'=' '{print $2}' || output --error "Failed to get $ARG_VARIABLE ." || exit 1
}
