#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private git'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private git <repo> <git-args…>
#
# @repo        : <repo>       | Repository (positional)
# @wrap        : <git-args…>  | Passed to git unchanged, with git completion
# ==============================================================================
function arguments {
    # Repository — fzf offers the registered ones when missing
    arg_direct @repo --description "Repository" --fzf --option-cmd "mgit_repo_names private"

    # Everything else goes to git — and so does the completion
    arg_wrap "git"
}
