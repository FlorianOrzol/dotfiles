#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit public add'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit public add <repo> <path>
#
# @repo        : <repo>   | Target repository (positional)
# @path        : <path>   | File or directory below $HOME (positional)
# ==============================================================================
function arguments {
    # Repository — fzf offers the registered ones when missing
    arg_direct @repo --description "Repository" --fzf --option-cmd "mgit_repo_names public"

    # File or directory to add — native path completion
    arg_direct @path --description "File or directory below \$HOME" --type path
}
