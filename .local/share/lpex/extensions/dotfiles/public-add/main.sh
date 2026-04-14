#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: dotfiles public-add
# Adds files or directories to the public bare Git repository.
# Maintains an internal tracking list to bypass global .gitignore rules.
# ==============================================================================

function extension_start() {
    # 1. Resolve Targets (Support explicit flags and positional fallbacks)
    local target_files=("${ARG_FILES[@]}")
    
    local tracker_file="$PATH_EXTENSION_DATA/public_tracked.txt"
    mkdir -p "$PATH_EXTENSION_DATA"

    # 2. Iterate and Process Targets
    for target in "${target_files[@]}"; do
        # Securely expand to absolute path, handling filenames starting with dashes
        local abs_target
        abs_target=$(realpath -m -- "$target")

        # --- Safety Gate ---
        output --warn "Target: $abs_target"
        if ! question "Do you really want to add this to the PUBLIC repo?" --default-no; then
            output --info "Skipped $target."
            continue
        fi

        output --info "Adding to Public Repo: $abs_target"
        
        # --- Git Execution ---
        # We use -f (force) to ensure the file is tracked even if a global .gitignore is active.
        if lx cmd --run "/usr/bin/git --git-dir=$HOME/.git-dotfiles/public --work-tree=$HOME add -f '$abs_target'" --quiet --error-msg "Git add failed for $target"; then
            
            # --- Smart Tracking ---
            # Append the absolute path to our local tracker database so 'push-all' 
            # can aggressively scan it for new files later.
            if ! grep -Fxq "$abs_target" "$tracker_file" 2>/dev/null; then
                echo "$abs_target" >> "$tracker_file"
                output --ok "Successfully forced '$target' into Public tracking list!"
            else
                output --info "'$target' is already in the tracking list."
            fi
        fi
    done
}
