#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'recovery/disk'.
# ==============================================================================

# --- function arguments ---
# @desc_short  : Registers CLI arguments for the disk recovery workflow.
# @usage       : lpex homelab recovery disk [--observer <name>] [--target <host>]
#              :                            [--source <host>] [--pool <name>] [--disk <dev>]
#
# @options     : --observer  | Observer to run the recovery script on (default: OBSERVER_PRIMARY)
#              : --target    | Host to restore data to (default: host_1)
#              : --source    | Host holding the backup data (default: host_2)
#              : --pool      | Top-level ZFS pool name (interactive on observer if omitted)
#              : --disk      | Block device on target host (interactive on observer if omitted)
# ==============================================================================
function arguments {
    # --observer: which observer runs job-disk-recovery.sh (defaults to primary in main)
    arg_value @observer \
        --description "Observer to run the recovery on (default: ${OBSERVER_PRIMARY})" \
        --option-cmd "get_observers"

    # --target: repaired host that will receive the data
    arg_value @target \
        --description "Host to restore data to (default: host_1)" \
        --option-cmd "get_hosts"

    # --source: backup host that holds the last good data copy
    arg_value @source \
        --description "Host holding the backup data (default: host_2)" \
        --option-cmd "get_hosts"

    # --pool: top-level ZFS pool — derived from ZFS_POOLS in homelab.conf
    # If omitted, job-disk-recovery.sh prompts interactively on the observer
    arg_value @pool \
        --description "Top-level ZFS pool to recover (interactive if omitted)" \
        --option-cmd "printf '%s\n' \"\${ZFS_POOLS[@]}\" | sed 's|/.*||' | sort -u"

    # --disk: block device on the target host (e.g. sdd or /dev/sdd)
    # If omitted, job-disk-recovery.sh shows lsblk and prompts interactively
    arg_value @disk \
        --description "Block device on target host (interactive if omitted, e.g. sdd)"

    # --yes: skip all confirmation prompts — use for automated/unattended recovery
    arg_flag @yes \
        --description "Skip all confirmation prompts (auto-confirm all steps)"
}
