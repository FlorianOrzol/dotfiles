#!/bin/bash

# ==============================================================================
# --- Arguments Definition ---
# Module: dotfiles private-add
# ==============================================================================

function arguments() {
	arg_value @files \
		--type "path" \
		--multi \
		--description "Files/Folders to add to the private repo"
}

