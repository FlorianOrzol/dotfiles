#!/bin/bash

# ==============================================================================
# --- Arguments Definition ---
# Module: dotfiles public-add
# ==============================================================================

function arguments() {
	# Accept one or multiple files/directories to add.
	# The --type "path" triggers native directory/file completion in Fish.
	arg_value @files \
		--type "path" \
		--multi \
		--description "Files/Folders to add to the public repo"
}

