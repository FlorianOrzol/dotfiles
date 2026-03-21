#!/bin/bash
function extension_start() {
    local public_git="$HOME/.git-dotfiles/public"
    local private_git="$HOME/.git-dotfiles/private"
    local timestamp=$(date "+%Y-%m-%d %H:%M")
    
    local msg="${ARG_MESSAGE[*]}"
    [[ -z "$msg" ]] && msg="${ARGS_EXTENSION_ARRAY[*]}"
    [[ -z "$msg" ]] && msg="Auto update $timestamp"

    # Secondary Security Layer (User request: Keep .gitignore with *)
    if [[ ! -f "$HOME/.gitignore" ]]; then
        output --warn "No .gitignore found in home. Creating default to ignore everything."
        echo "*" > "$HOME/.gitignore"
    fi

    # Helper function to process tracking lists safely
    process_repo() {
        local repo_type="$1"
        local git_dir="$2"
        local tracker_file="$PATH_EXTENSION_DATA/${repo_type}_tracked.txt"
        
        output --section "Syncing $repo_type Repo"
        
        if [[ ! -f "$tracker_file" ]]; then
            output --info "No explicit paths tracked yet. Use '$repo_type-add' first."
            return 0
        fi

        # 1. Update all currently known tracked files (catch modifications/deletions)
        lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME add -u" 2>/dev/null || true
        
        # 2. Iterate through our Smart Tracker list and force-add them explicitly.
        #    This forces Git to scan INSIDE these specific directories for brand new files
        #    even though the global .gitignore blocks them.
        output --info "Scanning tracked directories for new files..."
        while IFS= read -r target_path; do
            # Only attempt to add if the path still exists on disk
            if [[ -e "$target_path" ]]; then
                # We use -f to punch through the global .gitignore!
                lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME add -f '$target_path'" 2>/dev/null || true
            fi
        done < "$tracker_file"
        
        # 3. Commit and Push if changes exist
        if ! /usr/bin/git --git-dir=$git_dir --work-tree=$HOME diff-index --quiet HEAD --; then
            lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME commit -m '$msg'"
            
            output --info "Pushing..."
            if lx cmd --no-error-msg --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME push -u origin HEAD"; then
                output --ok "$repo_type Repo successfully pushed."
            else
                output --error "Failed to push $repo_type Repo."
            fi
        else
            output --info "No changes detected."
        fi
    }

    # Execute for both repositories
    process_repo "public" "$public_git"
    process_repo "private" "$private_git"
}
