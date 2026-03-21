function extension_start() {
    # ==============================================================================
    # --- LPEX Dotfiles Sync Engine ---
    # Automates the synchronization of bare Git repositories (public/private).
    # Commits and pushes only when actual changes are detected.
    # ==============================================================================

    local public_git="$HOME/.git-dotfiles/public"
    local private_git="$HOME/.git-dotfiles/private"
    local timestamp=$(date "+%Y-%m-%d %H:%M")
    
    # 1. Determine Commit Message
    local msg="${ARG_MESSAGE[*]}"
    [[ -z "$msg" ]] && msg="${ARGS_EXTENSION_ARRAY[*]}"
    [[ -z "$msg" ]] && msg="Auto update $timestamp"

    # 2. Security Check
    if [[ ! -f "$HOME/.gitignore" ]]; then
        output --warn "No .gitignore found in home. Creating default to ignore everything."
        echo "*" > "$HOME/.gitignore"
    fi

    # ==========================================================================
    # --- Sync Public Repository ---
    # ==========================================================================
    output --section "Syncing Public Repo"
    
    lx cmd --quiet --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME add ." 2>/dev/null || true
    # FIX: Add -u to ensure already tracked files in ignored directories get updated!
    lx cmd --quiet --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME add -u" 2>/dev/null || true
    
    if ! /usr/bin/git --git-dir=$public_git --work-tree=$HOME diff-index --quiet HEAD --; then
        lx cmd --quiet --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME commit -m '$msg'"
        
        output --info "Pushing Public Repo..."
        if lx cmd --no-error-msg --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME push -u origin HEAD"; then
            output --ok "Public Repo successfully pushed."
        else
            output --error "Failed to push Public Repo. Please check git status manually."
        fi
    else
        output --info "No changes detected in Public Repo."
    fi

    # ==========================================================================
    # --- Sync Private Repository ---
    # ==========================================================================
    output --section "Syncing Private Repo"
    
    lx cmd --quiet --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -u" 2>/dev/null || true
    
    if ! /usr/bin/git --git-dir=$private_git --work-tree=$HOME diff-index --quiet HEAD --; then
        lx cmd --quiet --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME commit -m '$msg'"
        
        output --info "Pushing Private Repo..."
        if lx cmd --no-error-msg --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME push -u origin HEAD"; then
            output --ok "Private Repo successfully pushed."
        else
            output --error "Failed to push Private Repo. Please check git status manually."
        fi
    else
        output --info "No changes detected in Private Repo."
    fi
}
