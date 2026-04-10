#!/bin/bash

# ==============================================================================
# --- Main Execution ---
# Module: dotfiles private
# Wrapper to execute raw git commands against the private bare repository.
# ==============================================================================

function extension_start() {
	# Path to the bare repository for sensitive/private dotfiles
	local private_git="$HOME/.git-dotfiles/private"
	
	# Execute the git command.
	# We pass all arguments collected by the framework (ARGS_EXTENSION_ARRAY)
	# directly to git, effectively simulating a normal git execution.
	lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME ${ARG_GIT[@]}"
}

