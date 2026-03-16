#!/bin/bash

# ==============================================================================
# --- Main Execution ---
# Module: dotfiles public
# Wrapper to execute raw git commands against the public bare repository.
# ==============================================================================

function extension_start() {
	# Path to the bare repository for publicly accessible dotfiles
	local public_git="$HOME/.git-dotfiles/public"
	
	# Execute the git command.
	# We pass all arguments collected by the framework (ARGS_EXTENSION_ARRAY)
	# directly to git, effectively simulating a normal git execution.
	lx cmd --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME ${ARGS_EXTENSION_ARRAY[*]}"
}

