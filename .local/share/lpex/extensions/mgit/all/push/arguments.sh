#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit all push'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit all push [--message <text>]
#
# @options     : --message <text>| Commit message (default: timestamp)
# ==============================================================================
function arguments {
    # Commit message — all words up to the next flag
    arg_value @message --multi --description "Commit message (default: timestamp)"
}
