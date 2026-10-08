#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private rm'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private rm <repo> --path <path>
#
# @repo        : <repo>         | Repository (positional, required first)
# @options     : --path <path>  | File or directory below $HOME
# ==============================================================================
function arguments {
    # Repository first and required — completion offers only repositories until it is given
    arg_direct @repo --required --description "Repository" --fzf --option-cmd "mgit_repo_names private"

    # Path to stop tracking — native path completion
    arg_value @path --description "File or directory below \$HOME" --type path
}
