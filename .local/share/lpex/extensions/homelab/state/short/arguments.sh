#!/bin/bash

# --- arguments ---
# @desc_short       : Registers CLI arguments for the status overview submodule.
# @usage            : lpex homelab status overview [--detail]
#
# (no flags)  → compact one-pager (default)
# --detail    → detailed status with full per-device information
# ==============================================================================
function arguments {
    arg_flag @detail --description "Detailed status with full per-device information"
}
