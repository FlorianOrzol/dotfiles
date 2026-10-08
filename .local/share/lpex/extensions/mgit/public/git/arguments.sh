#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit public git'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit public git <repo> <git-args…>
#
# @repo        : <repo>       | Repository (positional, required first — sets --git-dir/--work-tree)
# @wrap        : <git-args…>  | Passed to git unchanged, with git completion
# ==============================================================================
function arguments {
    # Repository first and required — completion offers only repositories until it is given
    arg_direct @repo --required --description "Repository" --fzf --option-cmd "mgit_repo_names public"

    # Everything else goes to git — and so does the completion
    arg_wrap "git"
}
