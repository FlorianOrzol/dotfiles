#!/bin/bash
# ==============================================================================
# @meta_name        : config/list/arguments.sh
# @desc_short       : CLI arguments for listing all config entries.
# ==============================================================================

# --- function arguments ---
# @desc_short   : Registers CLI arguments for config list.
# @usage        : lpex homelab config list [--filter <string>]
#
# @options      : --filter | Optional substring filter (e.g. HOST, OBSERVER, ZFS)
# ==============================================================================
function arguments {
    arg_value @filter --description "Optional filter string (e.g. HOST, OBSERVER, ZFS)"
}
