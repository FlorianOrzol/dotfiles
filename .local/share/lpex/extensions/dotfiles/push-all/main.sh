#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: dotfiles push-all
# Synchronizes both the public and private Git repositories. 
# Utilizes the 'Smart Tracker' lists to safely scan specific directories 
# while ignoring the rest of the filesystem.
# ==============================================================================

function extension_start() {
    local public_git="$HOME/.git-dotfiles/public"
    local private_git="$HOME/.git-dotfiles/private"
    local timestamp=$(date "+%Y-%m-%d %H:%M")
    
    # 1. Resolve Commit Message
    local msg="${ARG_MESSAGE[*]}"
    if [[ -z "$msg" ]]; then
        msg="${ARGS_EXTENSION_ARRAY[*]}"
    fi
    if [[ -z "$msg" ]]; then
        msg="Auto update $timestamp"
    fi

    # 2. Security Check (Enforce global ignorance)
    if [[ ! -f "$HOME/.gitignore" ]]; then
        output --warn "No .gitignore found in home. Creating default to ignore everything."
        echo "*" > "$HOME/.gitignore"
    fi

    # ==========================================================================
    # --- Repository Processing Engine ---
    # ==========================================================================
    process_repo() {
        local repo_type="$1"
        local git_dir="$2"
        local tracker_file="$PATH_EXTENSION_DATA/${repo_type}_tracked.txt"
        local exclude_file="$PATH_EXTENSION_DATA/${repo_type}_excluded.txt"
        
        output --section "Syncing ${repo_type^} Repo"
        
        if [[ ! -f "$tracker_file" ]]; then
            output --info "No explicit paths tracked yet. Use '${repo_type}-add' first."
            return 0
        fi

        # Phase 1: Update existing index
        # Captures modifications to files already firmly anchored in the index.
        lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME add -u" 2>/dev/null || true
        
        # Phase 2: Aggressive Directory Scanning
        # Iterates through the Smart Tracker database and uses 'add -f' to bypass 
        # the global .gitignore, ensuring new files within these specific folders are caught.
        output --info "Scanning tracked directories for new files..."
        while IFS= read -r target_path; do
            if [[ -e "$target_path" ]]; then
                lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME add -f '$target_path'" 2>/dev/null || true
            fi
        done < "$tracker_file"

        # Phase 3: Enforce Exclusions (Blacklist)
        # Strips out any specific files the user intentionally deleted via the 'rm' modules.
        if [[ -f "$exclude_file" ]]; then
            while IFS= read -r exclude_path; do
                lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME rm --cached -r '$exclude_path'" 2>/dev/null || true
            done < "$exclude_file"
        fi
        
        # Phase 4: Commit and Push
        if ! /usr/bin/git --git-dir=$git_dir --work-tree=$HOME diff-index --quiet HEAD --; then
            lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME commit -m '$msg'"
            
            output --info "Pushing..."
            if lx cmd --no-error-msg --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME push -u origin HEAD"; then
                output --ok "${repo_type^} Repo successfully pushed."
            else
                output --error "Failed to push ${repo_type^} Repo."
            fi
        else
            output --info "No changes detected."
        fi
    }

    # Execute engine for both zones
    process_repo "public" "$public_git"
    process_repo "private" "$private_git"
}
