#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private status'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private status [repo]
#
# @repo        : [repo]   | Only this repository (positional)
# ==============================================================================
function arguments {
    # Optional repository — without it the action covers the whole area
    arg_direct @repo --description "Repository (default: all of the area)" --option-cmd "mgit_repo_names private"
}
