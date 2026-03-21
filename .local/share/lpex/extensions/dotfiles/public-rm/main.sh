#!/bin/bash
function extension_start() {
    local target_files=("${ARG_FILES[@]}")
    [[ ${#target_files[@]} -eq 0 ]] && target_files=("${ARGS_EXTENSION_ARRAY[@]}")
    
    if [[ ${#target_files[@]} -eq 0 ]]; then
        output --error "Please specify files/folders to remove (e.g. lpex dotfiles public-rm ~/.bashrc)"
        return 1
    fi
    
    local tracker_file="$PATH_EXTENSION_DATA/public_tracked.txt"
    local exclude_file="$PATH_EXTENSION_DATA/public_excluded.txt"

    for target in "${target_files[@]}"; do
        local abs_target=$(realpath -m -- "$target")
        output --info "Removing from Public Repo: $abs_target"
        
        # Remove from Git index
        if lx cmd --run "/usr/bin/git --git-dir=$HOME/.git-dotfiles/public --work-tree=$HOME rm --cached -r '$abs_target'" --quiet --error-msg "Git rm failed for $target"; then
            
            # Logic 1: Was this exact path in the tracked list? Remove it.
            if grep -Fxq "$abs_target" "$tracker_file" 2>/dev/null; then
                # Delete the line from tracker_file
                grep -v -Fx "$abs_target" "$tracker_file" > "${tracker_file}.tmp" && mv "${tracker_file}.tmp" "$tracker_file"
                output --ok "Removed '$target' from the tracking list."
            else
                # Logic 2: It wasn't explicitly tracked, which means it's a sub-file of a tracked directory.
                # We add it to an exclude list so push-all doesn't re-add it automatically!
                if ! grep -Fxq "$abs_target" "$exclude_file" 2>/dev/null; then
                    echo "$abs_target" >> "$exclude_file"
                    output --warn "Added '$target' to the EXCLUDE list to prevent auto-re-adding."
                fi
            fi
        fi
    done
}
