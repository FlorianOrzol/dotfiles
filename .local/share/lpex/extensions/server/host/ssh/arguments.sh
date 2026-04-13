#!/bin/bash
# ==============================================================================
# @meta_module      : server host ssh
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server host ssh'.
#
# @arg_values       : --node | Target Proxmox node (pve101, pve102, pve103)
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Proxmox Node (pve101, pve102, pve103)" --option "pve101" --option "pve102" --option "pve103"
}
