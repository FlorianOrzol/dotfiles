#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private add'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private add <repo> --path <path>
#
# @repo        : <repo>         | Repository (positional, required first)
# @options     : --path <path>  | File or directory below $HOME
# ==============================================================================
function arguments {
    # Repository first and required — completion offers only repositories until it is given
    arg_direct @repo --required --description "Repository" --fzf --option-cmd "mgit_repo_names private"

    # File or directory to add — native path completion
    arg_value @path --description "File or directory below \$HOME" --type path
}
