#!/bin/bash
function extension_start() {
    local public_git="$HOME/.git-dotfiles/public"
    local private_git="$HOME/.git-dotfiles/private"
    local timestamp=$(date "+%Y-%m-%d %H:%M")
    local msg="${ARG_MESSAGE[*]:-${ARGS_EXTENSION_ARRAY[*]}}"
    [[ -z "$msg" ]] && msg="Auto update $timestamp"

    process_repo() {
        local repo_type="$1"
        local git_dir="$2"
        local tracker_file="$PATH_EXTENSION_DATA/${repo_type}_tracked.txt"
        local exclude_file="$PATH_EXTENSION_DATA/${repo_type}_excluded.txt"
        
        output --section "Syncing $repo_type Repo"
        [[ ! -f "$tracker_file" ]] && { output --info "No explicit paths tracked yet."; return 0; }

        # 1. Update known files
        lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME add -u" 2>/dev/null || true
        
        # 2. Add tracked directories (Finds new files)
        output --info "Scanning tracked directories..."
        while IFS= read -r target_path; do
            [[ -e "$target_path" ]] && lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME add -f '$target_path'" 2>/dev/null || true
        done < "$tracker_file"

        # 3. ENFORCE EXCLUDES (Strip out things they explicitly removed)
        if [[ -f "$exclude_file" ]]; then
            while IFS= read -r exclude_path; do
                lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME rm --cached -r '$exclude_path'" 2>/dev/null || true
            done < "$exclude_file"
        fi
        
        # 4. Commit and Push
        if ! /usr/bin/git --git-dir=$git_dir --work-tree=$HOME diff-index --quiet HEAD --; then
            lx cmd --quiet --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME commit -m '$msg'"
            if lx cmd --no-error-msg --run "/usr/bin/git --git-dir=$git_dir --work-tree=$HOME push -u origin HEAD"; then
                output --ok "$repo_type Repo successfully pushed."
            else
                output --error "Failed to push $repo_type Repo."
            fi
        else
            output --info "No changes detected."
        fi
    }

    process_repo "public" "$public_git"
    process_repo "private" "$private_git"
}
