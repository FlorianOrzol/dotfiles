#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: dotfiles private-rm
# Removes files from the private Git repository and intelligently updates 
# the internal tracking and exclusion lists.
# ==============================================================================

function extension_start() {
    # 1. Resolve Targets
    local target_files=("${ARG_FILES[@]}")
    fi
    
        return 1
    fi
    
    local tracker_file="$PATH_EXTENSION_DATA/private_tracked.txt"
    local exclude_file="$PATH_EXTENSION_DATA/private_excluded.txt"

    # 2. Iterate and Process
    for target in "${target_files[@]}"; do
        local abs_target
        abs_target=$(realpath -m -- "$target")
        output --info "Removing from Private Repo: $abs_target"
        
        # --- Git Execution ---
        if lx cmd --run "/usr/bin/git --git-dir=$HOME/.git-dotfiles/private --work-tree=$HOME rm --cached -r '$abs_target'" --quiet --error-msg "Git rm failed for $target"; then
            
            # --- Smart Tracker Maintenance ---
            if grep -Fxq "$abs_target" "$tracker_file" 2>/dev/null; then
                grep -v -Fx "$abs_target" "$tracker_file" > "${tracker_file}.tmp" && mv "${tracker_file}.tmp" "$tracker_file"
                output --ok "Removed '$target' from the tracking list."
            else
                if ! grep -Fxq "$abs_target" "$exclude_file" 2>/dev/null; then
                    echo "$abs_target" >> "$exclude_file"
                    output --warn "Added '$target' to the EXCLUDE list to prevent auto-re-adding."
                fi
            fi
        fi
    done
}
