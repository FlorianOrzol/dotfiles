#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Registers CLI arguments for setup/units/vm.
# ==============================================================================

function arguments {
    arg_direct @device \
        --description "VM ID to generate units on" \
        --fzf \
        --option-cmd "get_vms"
}
