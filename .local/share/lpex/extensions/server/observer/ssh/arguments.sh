#!/bin/bash
# ==============================================================================
# @meta_module      : server observer ssh
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server observer ssh'.
#
# @arg_values       : --node | Target Observer (pi1 or pi2)
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
}
