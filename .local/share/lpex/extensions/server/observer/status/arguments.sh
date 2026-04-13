#!/bin/bash
# ==============================================================================
# @meta_module      : server observer status
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server observer status'.
#
# @arg_values       : --node | Target Observer node (pi1 or pi2). Defaults to pi1.
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Observer (pi1 or pi2, default: pi1)" --option "pi1" --option "pi2"
    arg_flag  @all  --description "Show status for both pi1 and pi2 in one call"
}
