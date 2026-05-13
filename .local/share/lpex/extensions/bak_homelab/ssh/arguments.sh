#!/bin/bash
# ==============================================================================
# @meta_name        : ssh/arguments.sh
# @desc_short       : Defines CLI arguments for direct SSH access to devices.
# @usage            : lpex homelab ssh [device] [id]
# ==============================================================================

function arguments {
    arg_value @host --description "SSH into a host" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' \
            --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @observer --description "SSH into an observer" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'observers' \
            --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @container --description "Enter a container (pct enter via host)" \
        --option-cmd "cat '${FILE_CONTAINER_LIVE}' 2>/dev/null"

    arg_value @vm --description "SSH into a VM" \
        --option-cmd "cat '${FILE_VM_LIVE}' 2>/dev/null"
}
