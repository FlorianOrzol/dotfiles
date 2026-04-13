#!/bin/bash
# ==============================================================================
# @meta_module      : server host status
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server host status'.
#
# @arg_values       : --node | Target Proxmox node (pve101, pve102, pve103)
# @arg_flags        : --all  | Check all three PVE nodes in one call
# @arg_flags        : --live | Force live SSH query instead of reading from NFS cache
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Proxmox Node (pve101, pve102, pve103)" --option "pve101" --option "pve102" --option "pve103"
    arg_flag  @all  --description "Check all PVE nodes (pve101, pve102, pve103)"
    arg_flag  @live --description "Force a live SSH query instead of reading the NFS cache"
}
