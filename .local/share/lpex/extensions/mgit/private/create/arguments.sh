#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private create'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private create <repo> [--path <folder>] [--local-only]
#
# @repo        : <repo>        | Name of the new repository (positional, prompted when missing)
# @options     : --path <folder> | Project folder — without it a home repository
#                --local-only  | Skip the server API — the repository exists there already
# ==============================================================================
function arguments {
    # Repository first and required — completion offers nothing else until it is given
    arg_direct @repo --required --description "Name of the new repository"

    # Options after the name: their values are never taken as repository
    arg_value @path --description "Project folder (without or ~: home repository)" --type dir
    arg_flag @local_only --description "Skip the server API — repository exists there already"
}
