#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'mgit private apply'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments.
# @usage       : lpex mgit private apply [--collect]
#
# @options     : --collect | Copy the system files into the sources instead of installing
# ==============================================================================
function arguments {
    # Reverse direction: system → sources
    arg_flag @collect --description "Copy the system files into the sources instead of installing"
}
