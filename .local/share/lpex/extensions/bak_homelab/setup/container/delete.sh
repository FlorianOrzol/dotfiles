#!/bin/bash
# ==============================================================================
# @meta_name        : setup/container/delete.sh
# @desc_short       : Container-Löschung via pct. Sourced by setup/container/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_delete ---
# @desc_short   : Stops and destroys an LXC container on its host.
# ==============================================================================
function action_delete {
    local host_id
    # Find which host currently runs this container via NFS live files
    host_id=$(host_for_container "$ARG_ID") || return 1

    WARN "This will permanently delete container ct-${ARG_ID} on host ${host_id}."

    # Stop first (ignore error if already stopped), then destroy
    run_on_host "$host_id" "pct stop ${ARG_ID} 2>/dev/null; pct destroy ${ARG_ID}" || return 1

    OK "Container ct-${ARG_ID} deleted."
}
