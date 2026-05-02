#!/bin/bash
# ==============================================================================
# @meta_name        : setup/vm/_delete.sh
# @desc_short       : VM-Löschung via qm. Sourced by setup/vm/main.sh.
# ==============================================================================

# ==============================================================================
# --- _action_delete ---
# @desc_short   : Stops and destroys a VM on its host.
# ==============================================================================
function _action_delete {
    # Find the host that currently runs this VM
    local host_id
    host_id=$(_host_for_container "$ARG_ID") || return 1

    WARN "This will permanently delete VM vm-${ARG_ID} on host ${host_id}."

    # Stop first (ignore error if already stopped), then destroy
    _run_on_host "$host_id" "qm stop ${ARG_ID} 2>/dev/null; qm destroy ${ARG_ID}" || return 1

    OK "VM vm-${ARG_ID} deleted."
}
