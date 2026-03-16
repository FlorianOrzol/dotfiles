#!/bin/bash

# ==============================================================================
# --- Main Execution ---
# Module: dotfiles private-rm
# Removes a file or directory from the private git repository index.
# ==============================================================================

function extension_start() {
	local private_git="$HOME/.git-dotfiles/private"
	
	# 1. Resolve arguments
	local target_files=("${ARG_FILES[@]}")
	if [[ ${#target_files[@]} -eq 0 ]]; then
		target_files=("${ARGS_EXTENSION_ARRAY[@]}")
	fi

	# Ensure we actually have something to do
	if [[ ${#target_files[@]} -eq 0 ]]; then
		output --error "No files or directories specified."
		return 1
	fi

	# 2. Iterate and remove from index
	for path in "${target_files[@]}"; do
		# We only remove it from the git index (--cached) so the local file stays intact on disk
		if lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME rm --cached "; then
			output --ok "Removed  from Private Repo index."
		else
			output --error "Failed to remove  from Private Repo."
		fi
	done
}

