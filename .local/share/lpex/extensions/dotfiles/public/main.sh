function extension_start() {
    local public_git="$HOME/.git-dotfiles/public"
    lx cmd --run "/usr/bin/git --git-dir=$public_git --work-tree=$HOME ${ARGS_EXTENSION_ARRAY[*]}"
}
