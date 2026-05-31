#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for setup/units/host.
# ==============================================================================

function arguments {
    arg_direct @device \
        --description "Host to generate units on" \
        --fzf \
        --option-cmd "get_hosts"
}
