#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit all list'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit all list [--files]
#
# @options     : --files  | Also list every tracked file
# ==============================================================================
function arguments {
    # Full file listing on demand
    arg_flag @files --description "Also list every tracked file"
}
