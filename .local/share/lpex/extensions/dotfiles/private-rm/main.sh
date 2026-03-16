function extension_start() {
    local private_git="$HOME/.git-dotfiles/private"
    local target_files=("${ARG_FILES[@]}")
    [[ ${#target_files[@]} -eq 0 ]] && target_files=("${ARGS_EXTENSION_ARRAY[@]}")
    [[ ${#target_files[@]} -eq 0 ]] && { output --error "No files specified."; return 1; }

    for path in "${target_files[@]}"; do
        lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME rm --cached '$path'"
        output --ok "Removed $path from Private Repo"
    done
}
