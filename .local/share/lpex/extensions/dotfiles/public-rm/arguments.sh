#!/bin/bash

# ==============================================================================
# --- Arguments Definition ---
# Module: dotfiles public-rm
# ==============================================================================

function arguments() {
	# Accept one or multiple files/directories to remove.
	arg_value @files \
		--type "path" \
		--multi \
		--description "Files/Folders to remove from the public repo"
}

