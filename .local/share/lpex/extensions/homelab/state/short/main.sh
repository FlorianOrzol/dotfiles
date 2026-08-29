#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Entry point for lpex homelab status overview.
# ==============================================================================

source "${PATH_EXTENSION}/_lib.sh"
source "${PATH_EXTENSION}/_compact.sh"

# ==============================================================================
# --- extension_start ---
# ==============================================================================
function extension_start {
	MOUNT_POOL_FAST=/mnt/pool_fast          # NFS fast pool mount — overridden by config.conf
    # Abort early if the NFS monitoring state is not reachable
    _status_check_mount

    # Read HA container IDs from NFS share (written by observer on change) — no SSH needed
    _status_fetch_ha_ids || WARN "ha_clients not yet on share — deploy observer or run obs-ha-clients-watch manually"

    # Read the removal markers so deliberately unprotected containers stay visible
    _status_fetch_ha_removed

	_action_compact
}
