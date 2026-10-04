#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit public git'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit public git <repo> <git-args…>
#
# @repo        : <repo>       | Repository (positional)
# @wrap        : <git-args…>  | Passed to git unchanged, with git completion
# ==============================================================================
function arguments {
    # Repository — fzf offers the registered ones when missing
    arg_direct @repo --description "Repository" --fzf --option-cmd "mgit_repo_names public"

    # Everything else goes to git — and so does the completion
    arg_wrap "git"
}
