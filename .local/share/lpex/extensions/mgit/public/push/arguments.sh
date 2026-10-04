#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit public push'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit public push [repo] [--message <text>]
#
# @repo        : [repo]          | Only this repository (positional)
# @options     : --message <text>| Commit message (default: timestamp)
# ==============================================================================
function arguments {
    # Defined before @repo: its words are consumed and never taken as repository
    arg_value @message --multi --description "Commit message (default: timestamp)"

    # Optional repository — without it the action covers the whole area
    arg_direct @repo --description "Repository (default: all of the area)" --option-cmd "mgit_repo_names public"
}
