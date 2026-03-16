function extension_start() {
    # --------------------------------------------------------------------------
    # LPEX Dotfiles Sync Engine
    # This script handles the automated synchronization of both the public
    # and private bare git repositories. It intelligently handles commits
    # only when actual changes are detected and attempts to push them upstream.
    # --------------------------------------------------------------------------

    # Core configuration paths for the bare git repositories
    local public_git="$HOME/.git-dotfiles/public"
    local private_git="$HOME/.git-dotfiles/private"
    
    # Generate a timestamp for automated commit messages
    local timestamp=$(date "+%Y-%m-%d %H:%M")
    
    # Determine the commit message:
    # 1. Use explicitly provided --message if available
    # 2. Fallback to any remaining loose arguments passed to the command
    # 3. Fallback to an automated timestamp string
    local msg="${ARG_MESSAGE[*]}"
    [[ -z "$msg" ]] && msg="${ARGS_EXTENSION_ARRAY[*]}"
    [[ -z "$msg" ]] && msg="Auto update $timestamp"

    # Security check: Ensure a global .gitignore exists in the home directory
    # so that untracked private files do not accidentally leak into the public repo.
    if [[ ! -f "$HOME/.gitignore" ]]; then
        output --warn "No .gitignore found in home. Creating default to ignore everything."
        echo "*" > "$HOME/.gitignore"
    fi

    # ==========================================================================
    # --- Sync Public Repository ---
    # ==========================================================================
    output --section "Syncing Public Repo"
    
    # Add all changes (respecting .gitignore) to the staging area
    lx cmd --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME add ."
    
    # Check if there are staged changes using diff-index.
    # If the command fails (returns non-zero), it means changes exist.
    if ! /usr/bin/git --git-dir=$public_git --work-tree=$HOME diff-index --quiet HEAD --; then
        
        # Commit the changes
        lx cmd --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME commit -m '$msg'"
        
        # Attempt to push to the upstream origin.
        # We use if/then here to check the success of lx cmd, because lx cmd returns 
        # the exit code of the executed command.
        if lx cmd --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME push -u origin HEAD"; then
            output --ok "Public Repo successfully pushed."
        else
            output --error "Failed to push Public Repo. See details above."
        fi
    else
        output "- No changes detected in Public Repo."
    fi

    # ==========================================================================
    # --- Sync Private Repository ---
    # ==========================================================================
    output --section "Syncing Private Repo"
    
    # For the private repo, we only add updates to ALREADY TRACKED files (-u).
    # We do NOT want to automatically track new files in the private repo unless
    # explicitly added via `dotfiles private-add`.
    lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -u"
    
    # Check if there are staged changes
    if ! /usr/bin/git --git-dir=$private_git --work-tree=$HOME diff-index --quiet HEAD --; then
        
        # Commit the changes
        lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME commit -m '$msg'"
        
        # Attempt to push, checking the exit code properly.
        if lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME push -u origin HEAD"; then
            output --ok "Private Repo successfully pushed."
        else
            output --error "Failed to push Private Repo. Manual intervention required (e.g. git pull)."
        fi
    else
        output "- No changes detected in Private Repo."
    fi
}
