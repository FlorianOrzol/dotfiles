#!/bin/bash
# ==============================================================================
# @meta_name        : _deploy.sh
# @desc_short       : SSH key actions — sourced by setup/ssh-keys/main.sh.
#
# Delegation principle:
#   LPEX does not manage SSH keys directly. All key work is delegated to
#   OBSERVER_PRIMARY via observer scripts. The observer has direct SSH access
#   to all devices and is the single source of truth for key material.
#
#   Observer scripts called:
#     obs-ssh-keys-deploy.sh  <device_type> <device_name> [--force]
#     obs-ssh-known-hosts.sh  <device_type> <device_name>
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"  # observer reachability check

# ==============================================================================
# --- action_deploy ---
# @desc_short  : Delegates SSH key deployment for a device to OBSERVER_PRIMARY.
#                Observer generates key pair if needed, deploys private key to
#                device, and distributes pubkey to all devices that need access.
# @parameter   : $1 | device_type | host | observer | container | vm
# @parameter   : $2 | device_name | logical device name (e.g. host_1)
# @parameter   : $3 | force       | non-empty = pass --force to observer script
# ==============================================================================
function action_deploy {
    local device_type="$1" device_name="$2" force="$3"

    # Observer must be reachable — it performs all key operations.
    _check_observer || return 1

    INFO "[${device_name}] Delegating SSH key deployment to '${OBSERVER_PRIMARY}'..."

    # Build optional --force flag to forward to the observer script.
    local force_flag=""
    [[ -n "$force" ]] && force_flag="--force"

    # Run observer script — handles key generation, deployment and pubkey distribution.
    execute_on_device "$OBSERVER_PRIMARY" \
        "sudo obs-ssh-keys-deploy.sh ${device_type} ${device_name} ${force_flag}" || {
        ERROR "[${device_name}] Observer script 'obs-ssh-keys-deploy.sh' failed."
        return 1
    }

    OK "[${device_name}] SSH key deployment complete."
}

# ==============================================================================
# --- action_known_hosts ---
# @desc_short  : Delegates known_hosts update for a device to OBSERVER_PRIMARY.
#                Observer scans all homelab IPs and writes the result to the
#                device's /root/.ssh/known_hosts.
# @parameter   : $1 | device_type | host | observer | container | vm
# @parameter   : $2 | device_name | logical device name
# ==============================================================================
function action_known_hosts {
    local device_type="$1" device_name="$2"

    # Observer must be reachable — it performs the scan and deployment.
    _check_observer || return 1

    INFO "[${device_name}] Delegating known_hosts update to '${OBSERVER_PRIMARY}'..."

    # Run observer script — scans all device IPs and writes known_hosts on target.
    execute_on_device "$OBSERVER_PRIMARY" \
        "sudo obs-ssh-known-hosts.sh ${device_type} ${device_name}" || {
        ERROR "[${device_name}] Observer script 'obs-ssh-known-hosts.sh' failed."
        return 1
    }

    OK "[${device_name}] known_hosts updated."
}

# ==============================================================================
# --- _check_observer ---
# @desc_short  : Verifies that OBSERVER_PRIMARY is reachable via SSH.
#                Aborts with a clear error if not — all actions depend on it.
# ==============================================================================
function _check_observer {
    local obs_ip obs_user

    # Resolve observer connection details from config.
    obs_ip=$(get_device_ip "$OBSERVER_PRIMARY")         || return 1
    obs_user=$(get_device_ssh_user "$OBSERVER_PRIMARY") || return 1

    # Test SSH connectivity — key operations cannot proceed without observer.
    if ! ssh ${SSH_OPTS} "${obs_user}@${obs_ip}" "exit" 2>/dev/null; then
        ERROR "Observer '${OBSERVER_PRIMARY}' is not reachable — cannot delegate SSH key operations."
        return 1
    fi
}
