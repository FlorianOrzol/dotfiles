#!/bin/bash

# ==============================================================================
# --- Main Execution ---
# Module: dotfiles private-add
# Adds a file or directory strictly to the private git repository.
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

	# 2. Iterate and process each file/directory
	for path in "${target_files[@]}"; do
		local abs_path
		abs_path="$(realpath "$path")"
		
		# Force add (-f) ensures it gets tracked even if ignored by global .gitignore
		if lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -f '$abs_path'"; then
			output --ok "Successfully tracked '$abs_path' in Private Repo."
		else
			output --error "Failed to track '$abs_path'."
		fi
	done
}

