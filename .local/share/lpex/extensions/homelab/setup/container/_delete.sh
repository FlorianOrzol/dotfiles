#!/bin/bash
# ==============================================================================
# @meta_name        : setup/container/_delete.sh
# @desc_short       : Container-Löschung via pct. Sourced by setup/container/main.sh.
# ==============================================================================

# ==============================================================================
# --- _action_delete ---
# @desc_short   : Stops and destroys an LXC container on its host.
# ==============================================================================
function _action_delete {
    # Find the host that currently runs this container
    local host_id
    host_id=$(_host_for_container "$ARG_ID") || return 1

    WARN "This will permanently delete container ct-${ARG_ID} on host ${host_id}."

    # Stop first (ignore error if already stopped), then destroy
    _run_on_host "$host_id" "pct stop ${ARG_ID} 2>/dev/null; pct destroy ${ARG_ID}" || return 1

    OK "Container ct-${ARG_ID} deleted."
}
