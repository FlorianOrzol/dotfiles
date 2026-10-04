#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit public check'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit public check <repo>
#
# @repo        : <repo>   | Repository (positional)
# ==============================================================================
function arguments {
    # Repository — fzf offers the registered ones when missing
    arg_direct @repo --description "Repository" --fzf --option-cmd "mgit_repo_names public"
}
