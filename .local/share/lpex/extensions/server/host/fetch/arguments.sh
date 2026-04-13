#!/bin/bash
# ==============================================================================
# @meta_module      : server host fetch
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server host fetch'.
#
# @arg_values       : --node        | Target Proxmox node (pve101, pve102, pve103)
# @arg_values       : --remote-file | Absolute path on the host to fetch
# ==============================================================================
function arguments() {
    arg_value @node        --description "Target Proxmox Node" --option "pve101" --option "pve102" --option "pve103"
    arg_value @remote_file --description "Absolute path to the file or directory on the Host"
}
