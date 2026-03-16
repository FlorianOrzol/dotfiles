function extension_start() {
    local private_git="$HOME/.git-dotfiles/private"
    lx cmd --run "/usr/bin/git --git-dir=$private_git --work-tree=$HOME ${ARGS_EXTENSION_ARRAY[*]}"
}
