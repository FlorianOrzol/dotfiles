#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private create'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private create <repo> [--local-only]
#
# @repo        : <repo>        | Name of the new repository (positional, prompted when missing)
# @options     : --local-only  | Skip the server API — the repository exists there already
# ==============================================================================
function arguments {
    # Repository exists on the server already (or is created by the first push)
    arg_flag @local_only --description "Skip the server API — repository exists there already"

    # Name of the new repository — no list, it does not exist yet
    arg_direct @repo --description "Name of the new repository"
}
