#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: dotfiles public-rm
# Removes files from the public Git repository and intelligently updates 
# the internal tracking and exclusion lists.
# ==============================================================================

function extension_start() {
    # 1. Resolve Targets
    local target_files=("${ARG_FILES[@]}")
    fi
    
        return 1
    fi
    
    local tracker_file="$PATH_EXTENSION_DATA/public_tracked.txt"
    local exclude_file="$PATH_EXTENSION_DATA/public_excluded.txt"

    # 2. Iterate and Process
    for target in "${target_files[@]}"; do
        local abs_target
        abs_target=$(realpath -m -- "$target")
        output --info "Removing from Public Repo: $abs_target"
        
        # --- Git Execution ---
        if lx cmd --run "/usr/bin/git --git-dir=$HOME/.git-dotfiles/public --work-tree=$HOME rm --cached -r '$abs_target'" --quiet --error-msg "Git rm failed for $target"; then
            
            # --- Smart Tracker Maintenance ---
            # Logic A: If the user deleted the EXACT path they previously added, we remove it from the tracker.
            if grep -Fxq "$abs_target" "$tracker_file" 2>/dev/null; then
                grep -v -Fx "$abs_target" "$tracker_file" > "${tracker_file}.tmp" && mv "${tracker_file}.tmp" "$tracker_file"
                output --ok "Removed '$target' from the tracking list."
            else
                # Logic B: If they deleted a sub-file INSIDE a tracked directory, we must blacklist it.
                # Otherwise, the next 'push-all' will re-add it automatically.
                if ! grep -Fxq "$abs_target" "$exclude_file" 2>/dev/null; then
                    echo "$abs_target" >> "$exclude_file"
                    output --warn "Added '$target' to the EXCLUDE list to prevent auto-re-adding."
                fi
            fi
        fi
    done
}
