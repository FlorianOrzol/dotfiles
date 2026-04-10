#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: credentials init
# Performs isolated initialization and registration for the 'credentials' profile.
# ==============================================================================

function extension_start() {

	# creat dirs if not exist
	mkdir -p "$(dirname "$FILE_PRIVATE_GLOBALS")"

}
