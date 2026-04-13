#!/bin/bash
# ==============================================================================
# @meta_module      : server container ssh
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server container ssh'.
#
# @arg_values       : --ctid | Target container ID (fzf-selectable)
# ==============================================================================
function arguments() {
    arg_value @ctid --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
}
