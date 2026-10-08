#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private delete'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private delete <repo> [--local-only]
#
# @repo        : <repo>        | Repository to delete (positional)
# @options     : --local-only  | Keep it on the servers, only forget it on this machine
# ==============================================================================
function arguments {
    # Only remove the local git dir and registry entry
    arg_flag @local_only --description "Keep it on the servers, only forget it on this machine"

    # Repository — fzf offers the registered ones when missing
    arg_direct @repo --description "Repository" --fzf --option-cmd "mgit_repo_names private"
}
