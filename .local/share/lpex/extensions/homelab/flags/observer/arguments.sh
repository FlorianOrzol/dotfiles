#!/bin/bash
# ==============================================================================
# @meta_name        : flags/observer/arguments.sh
# @desc_short       : Defines CLI arguments for observer flag management.
# @usage            : lpex homelab flags observer <id> [flag-type] [action]
# ==============================================================================

function arguments {
    # 1. --- Observer ID (positional) -------------------------------------------

    arg_direct @id --description "Observer ID" --fzf \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'observers' \
            --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    # 2. --- Flag Type (mutually exclusive) -------------------------------------

    arg_value @unit-skip --description "Unit-skip flag: unit name to manage" --fzf \
        --option "obs-heartbeat.timer" \
        --option "obs-ha-clients-watch.timer" \
        --option "job-backup-nightly.timer" \
        --option "obs-health.timer" \
        --option "obs-primary-observer-watch.timer"

    arg_value @zfs-sync --description "ZFS-sync flag: host name to manage" --fzf \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' \
            --select --cols 'name' 2>/dev/null"

    # 3. --- Actions ------------------------------------------------------------

    arg_flag @set    --description "Set the flag (unit-skip)"
    arg_flag @remove --description "Remove the flag (unit-skip)"
    arg_flag @on     --description "Enable ZFS sync (zfs-sync)"
    arg_flag @off    --description "Disable ZFS sync (zfs-sync)"
    arg_flag @list   --description "List all active flags on this observer"

    # 4. --- Modifiers ----------------------------------------------------------

    arg_value @reason --description "Reason text for the flag (optional, for --set)"
}
