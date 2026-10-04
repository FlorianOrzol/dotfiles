#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private list'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private list [repo] [--files]
#
# @repo        : [repo]   | Only this repository (positional)
# @options     : --files  | Also list every tracked file
# ==============================================================================
function arguments {
    # Full file listing on demand
    arg_flag @files --description "Also list every tracked file"
    # Optional repository — without it the action covers the whole area
    arg_direct @repo --description "Repository (default: all of the area)" --option-cmd "mgit_repo_names private"
}
