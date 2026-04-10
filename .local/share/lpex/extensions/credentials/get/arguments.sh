#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: credentials get
# ==============================================================================

function arguments() {

	arg_value @variable \
		--option-cmd "cat '$FILE_PRIVATE_GLOBALS' | grep '^PRIV_' | awk -F'=' '{print \$1 \" # \" \$2}'" 
}
