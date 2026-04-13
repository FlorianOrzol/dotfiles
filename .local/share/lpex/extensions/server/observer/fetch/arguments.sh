#!/bin/bash
# ==============================================================================
# @meta_module      : server observer fetch
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server observer fetch'.
#
# @arg_values       : --node        | Target Observer (pi1 or pi2)
# @arg_values       : --remote-file | Absolute path on the Observer to fetch
# ==============================================================================
function arguments() {
    arg_value @node        --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
    arg_value @remote_file --description "Absolute path to the file or directory on the Observer"
}
