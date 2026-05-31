#!/bin/bash
# ==============================================================================
# @meta_name        : _run.sh
# @desc_short       : SSH helper for launching job-disk-recovery.sh on the observer.
#                     Sourced by recovery/disk/main.sh.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"  # common SSH flags

FILE_RECOVERY_SCRIPT="/opt/homelab/bin/jobs/job-disk-recovery.sh"  # script path on observer

# ==============================================================================
# --- action_run_recovery ---
# @desc_short  : SSHs to the observer with a TTY and runs job-disk-recovery.sh via sudo.
#                Passes only the args that were explicitly provided — the script handles
#                interactive defaults for any that are omitted.
# @usage       : action_run_recovery <observer> [target] [source] [pool] [disk]
# @parameter   : $1 | observer    | Observer device name (e.g. observer_1)
# @parameter   : $2 | name_target | Target host name (empty → script default)
# @parameter   : $3 | name_source | Source host name (empty → script default)
# @parameter   : $4 | pool_name   | Top-level pool name (empty → interactive on observer)
# @parameter   : $5 | disk_device | Block device on target (empty → interactive on observer)
# ==============================================================================
function action_run_recovery {
    local observer="$1"
    local name_target="$2"
    local name_source="$3"
    local pool_name="$4"
    local disk_device="$5"
    local auto_yes="$6"
    local ip user

    # Resolve observer connection details
    ip=$(get_device_ip "$observer")         || return 1
    user=$(get_device_ssh_user "$observer") || return 1

    # Build the remote command — append only the args that were explicitly provided
    local cmd="${FILE_RECOVERY_SCRIPT}"
    [[ -n "$name_target" ]] && cmd+=" --target '${name_target}'"
    [[ -n "$name_source" ]] && cmd+=" --source '${name_source}'"
    [[ -n "$pool_name"   ]] && cmd+=" --pool '${pool_name}'"
    [[ -n "$disk_device" ]] && cmd+=" --disk '${disk_device}'"
    [[ -n "$auto_yes"    ]] && cmd+=" --yes"

    INFO "Starting disk recovery on '${observer}' (${user}@${ip})..."
    # -tt forces PTY allocation even when LPEX pipes stdin — required for /dev/tty prompts
    ssh ${SSH_OPTS} -tt "${user}@${ip}" "$cmd"
}
