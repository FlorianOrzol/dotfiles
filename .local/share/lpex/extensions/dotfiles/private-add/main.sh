function extension_start() {
    # --------------------------------------------------------------------------
    # LPEX Dotfiles - Private Add
    # Adds a file or directory strictly to the private git repository.
    # --------------------------------------------------------------------------

    local private_git="$HOME/.git-dotfiles/private"
    
    local target_files=("${ARG_FILES[@]}")
    [[ ${#target_files[@]} -eq 0 ]] && target_files=("${ARGS_EXTENSION_ARRAY[@]}")

    if [[ ${#target_files[@]} -eq 0 ]]; then
        output --error "No files or directories specified."
        return 1
    fi

    for path in "${target_files[@]}"; do
        local abs_path="$(realpath "$path")"
        if lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME add -f '$abs_path'"; then
            output --ok "Successfully tracked '$abs_path' in Private Repo."
        else
            output --error "Failed to track '$abs_path'."
        fi
    done
}
