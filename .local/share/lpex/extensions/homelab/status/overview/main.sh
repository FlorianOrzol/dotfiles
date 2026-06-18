#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Entry point for lpex homelab status overview.
# ==============================================================================

source "${PATH_EXTENSION}/_lib.sh"
source "${PATH_EXTENSION}/_compact.sh"
source "${PATH_EXTENSION}/_detailed.sh"

# ==============================================================================
# --- extension_start ---
# ==============================================================================
function extension_start {
    # Abort early if the NFS monitoring state is not reachable
	SUBSECTION_WIDTH=130
    _status_check_mount || return 1

    # Fetch HA container IDs once via SSH — all views that need HA data share this result
    _status_fetch_ha_ids || WARN "Could not fetch HA container IDs from leader — HA section may be incomplete"

    # Route to the selected view; default to compact one-pager
    if (( ARG_DETAIL )); then
        _action_detailed
    else
        _action_compact
    fi
}
