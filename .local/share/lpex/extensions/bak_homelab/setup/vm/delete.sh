#!/bin/bash
# ==============================================================================
# @meta_name        : setup/vm/delete.sh
# @desc_short       : VM-Löschung via qm. Sourced by setup/vm/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_delete ---
# @desc_short   : Stops and destroys a VM on its host.
# ==============================================================================
function action_delete {
    local host_id
    # Find which host currently runs this VM via NFS live files
    host_id=$(host_for_vm "$ARG_ID") || return 1

    WARN "This will permanently delete VM vm-${ARG_ID} on host ${host_id}."

    # Stop first (ignore error if already stopped), then destroy
    run_on_host "$host_id" "qm stop ${ARG_ID} 2>/dev/null; qm destroy ${ARG_ID}" || return 1

    OK "VM vm-${ARG_ID} deleted."
}
