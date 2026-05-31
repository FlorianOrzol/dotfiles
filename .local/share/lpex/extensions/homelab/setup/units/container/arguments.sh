#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for setup/units/container.
# ==============================================================================

function arguments {
    arg_direct @device \
        --description "Container ID to generate units on" \
        --fzf \
        --option-cmd "get_containers"
}
