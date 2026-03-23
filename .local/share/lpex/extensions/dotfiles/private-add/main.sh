#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: dotfiles private-add
# Adds files or directories to the private bare Git repository.
# Maintains an internal tracking list to bypass global .gitignore rules.
# ==============================================================================

function extension_start() {
    # 1. Resolve Targets
    local target_files=("${ARG_FILES[@]}")
    if [[ ${#target_files[@]} -eq 0 ]]; then
        target_files=("${ARGS_EXTENSION_ARRAY[@]}")
    fi
    
    if [[ ${#target_files[@]} -eq 0 ]]; then
        output --error "Please specify files/folders to add (e.g. lpex dotfiles private-add ~/.ssh)"
        return 1
    fi
    
    local tracker_file="$PATH_EXTENSION_DATA/private_tracked.txt"
    mkdir -p "$PATH_EXTENSION_DATA"

    # 2. Iterate and Process Targets
    for target in "${target_files[@]}"; do
        local abs_target
        abs_target=$(realpath -m -- "$target")

        # --- Safety Gate ---
        output --warn "Target: $abs_target"
        if ! question "Do you really want to add this to the PRIVATE repo?" --default-no; then
            output --info "Skipped $target."
            continue
        fi

        output --info "Adding to Private Repo: $abs_target"
        
        # --- Git Execution ---
        if lx cmd --run "/usr/bin/git --git-dir=$HOME/.git-dotfiles/private --work-tree=$HOME add -f '$abs_target'" --quiet --error-msg "Git add failed for $target"; then
            
            # --- Smart Tracking ---
            if ! grep -Fxq "$abs_target" "$tracker_file" 2>/dev/null; then
                echo "$abs_target" >> "$tracker_file"
                output --ok "Successfully forced '$target' into Private tracking list!"
            else
                output --info "'$target' is already in the tracking list."
            fi
        fi
    done
}
