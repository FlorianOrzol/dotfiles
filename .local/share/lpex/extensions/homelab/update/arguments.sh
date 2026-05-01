#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : Defines CLI arguments for the update submodule.
# @usage            : lpex homelab update [device] [id] [flags]
# ==============================================================================

function arguments {
    # 1. --- Device Selection (mutually exclusive, optional when --all* used) -----

    arg_value @host --description "Host to update (ID from homelab_conf.db)" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' \
            --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @observer --description "Observer to update (ID from homelab_conf.db)" \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'observers' \
            --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    arg_value @container --description "Container to update (VMID)" \
        --option-cmd "cat '${FILE_CONTAINER_LIVE}' 2>/dev/null"

    arg_value @vm --description "VM to update (VMID)" \
        --option-cmd "cat '${FILE_VM_LIVE}' 2>/dev/null"

    # 2. --- Bulk Flags -----------------------------------------------------------

    arg_flag @all          --description "Update all observers + hosts sequentially"
    arg_flag @all-observers --description "Update all observers sequentially"
    arg_flag @all-hosts    --description "Update all hosts sequentially"
    arg_flag @all-clients  --description "Update all containers and VMs sequentially"

    # 3. --- Modifiers ------------------------------------------------------------

    arg_flag @dry-run  --description "Show upgradable packages only — no actual update"
    arg_flag @patches  --description "Apply pending patches after OS update"
}
