#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for setup/units/observer.
# ==============================================================================

function arguments {
    arg_direct @device \
        --description "Observer to generate units on" \
        --fzf \
        --option-cmd "get_observers"
}
