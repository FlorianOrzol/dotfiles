#!/bin/bash

# ==============================================================================
# --- Arguments Definition ---
# Module: dotfiles push-all
# ==============================================================================

function arguments() {
	arg_value @message \
		--multi \
		--description "Commit message (optional)"
}

