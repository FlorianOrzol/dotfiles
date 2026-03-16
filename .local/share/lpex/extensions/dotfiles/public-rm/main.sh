#!/bin/bash

# ==============================================================================
# --- Main Execution ---
# Module: dotfiles public-rm
# Removes a file or directory from the public git repository index.
# ==============================================================================

function extension_start() {
	local public_git="$HOME/.git-dotfiles/public"
	
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
		if lx cmd --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME rm --cached "; then
			output --ok "Removed  from Public Repo index."
		else
			output --error "Failed to remove  from Public Repo."
		fi
	done
}

