#!/bin/bash

# ==============================================================================
# --- Main Execution ---
# Module: dotfiles public-add
# Adds a file or directory to BOTH the public and private git repositories.
# ==============================================================================

function extension_start() {
	local public_git="$HOME/.git-dotfiles/public"
	local private_git="$HOME/.git-dotfiles/private"
	
	# 1. Resolve arguments
	# Did the user use explicitly named arguments (e.g. --files path) 
	# or just positional arguments (e.g. dotfiles public-add path)?
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
		# Resolve to an absolute path for safety to avoid git relative-path confusion
		local abs_path
		abs_path="$(realpath "$path")"
		
		# Interactive safety check
		if question "Add '$abs_path' to public (and private) repo?" --default-no; then
			
			# Force add (-f) ensures it gets tracked even if ignored by global .gitignore
			if lx cmd --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME add -f '$abs_path'"; then
				# If successful in public, automatically mirror it to the private backup repo
				lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -f '$abs_path'"
				output --ok "Successfully tracked '$abs_path' in both repos."
			else
				output --error "Failed to add '$abs_path' to public repo."
			fi
		else
			output --info "Skipped '$abs_path'."
		fi
	done
}

