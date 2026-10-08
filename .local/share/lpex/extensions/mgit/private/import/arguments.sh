#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private import'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private import <repo> [--path <folder>] [--branch <name>]
#
# @repo        : <repo>           | Name of the repository on the servers (positional)
# @options     : --path <folder>  | Project folder — without it a home repository
#                --branch <name>  | Branch to use (default: the server's default branch)
# ==============================================================================
function arguments {
    # Repository first and required — completion offers nothing else until it is given
    arg_direct @repo --required --description "Name of the repository on the servers" --option-cmd "mgit_server_repo_names private"

    # Options after the name: their values are never taken as repository
    arg_value @path --description "Project folder (without or ~: home repository)" --type dir
    arg_value @branch --description "Branch (default: the server's default branch)"
}
