function extension_start() {
    local public_git="$HOME/.git-dotfiles/public"
    local target_files=("${ARG_FILES[@]}")
    [[ ${#target_files[@]} -eq 0 ]] && target_files=("${ARGS_EXTENSION_ARRAY[@]}")
    [[ ${#target_files[@]} -eq 0 ]] && { output --error "No files specified."; return 1; }

    for path in "${target_files[@]}"; do
        lx cmd --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME rm --cached '$path'"
        output --ok "Removed $path from Public Repo"
    done
}
