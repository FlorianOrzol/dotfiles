# This file defines completions for the `keys` command.
# It delegates the completion logic directly to the `rbw` (Bitwarden CLI) command,
# meaning that `keys` will offer the same completions as `rbw`.
complete -c keys -w rbw
