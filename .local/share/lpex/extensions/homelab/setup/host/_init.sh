#!/bin/bash
# ==============================================================================
# @meta_name        : _init.sh
# @desc_short       : Host initialization logic — sourced by setup/host/main.sh.
#
# Steps:
#   1. SSH key    — deploy desktop key to host if not yet trusted
#   2. Dirs       — create /opt/homelab directory structure
#   3. Scripts    — push local mirror content to host via tar stream
#   4. Node name  — write logical device name to state file
#   5. Config     — deploy local config.conf as homelab.conf
#   6. Units      — generate systemd units from templates
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"  # common SSH flags

# ==============================================================================
# --- action_init ---
# @desc_short  : Runs all 6 initialization steps for a single host in sequence.
#                Aborts on first failure to avoid an inconsistent device state.
# @parameter   : $1 | device | Host name (e.g. host_1)
# @parameter   : $2 | force  | Non-empty = skip idempotency checks
# ==============================================================================
function action_init {
    local device="$1" force="$2"
    local host_ip proxy_ip proxy_user

    # Resolve host IP — abort if device is not in config.
    host_ip=$(get_device_ip "$device") || return 1

    # OBSERVER_PRIMARY is the designated proxy jump host for reaching internal devices.
    proxy_ip=$(get_device_ip "$OBSERVER_PRIMARY")         || return 1
    proxy_user=$(get_device_ssh_user "$OBSERVER_PRIMARY") || return 1

    INFO "=== Initializing host '${device}' (${host_ip}) ==="

    # Run all steps in order — abort immediately on any failure.
    _init_ssh_key   "$device" "$host_ip" "$proxy_ip" "$proxy_user" "$force" || return 1
    _init_dirs      "$device"                                                || return 1
    _init_scripts   "$device" "$host_ip" "$proxy_ip" "$proxy_user"          || return 1
    _init_node_name "$device"                                                || return 1
    _init_conf      "$device"                                                || return 1
    _init_units     "$device"                                                || return 1

    OK "Host '${device}' successfully initialized."
}

# ==============================================================================
# --- _init_ssh_key ---
# @desc_short  : Deploys the desktop's SSH public key to the host if not trusted.
# @parameter   : $1 | device      | Host name
# @parameter   : $2 | host_ip     | Resolved host IP address
# @parameter   : $3 | proxy_ip    | Observer IP for ProxyJump
# @parameter   : $4 | proxy_user  | Observer SSH user for ProxyJump
# @parameter   : $5 | force       | Non-empty = re-deploy key unconditionally
# ==============================================================================
function _init_ssh_key {
    local device="$1" host_ip="$2" proxy_ip="$3" proxy_user="$4" force="$5"

    INFO "[${device}] Step 1/6 — Checking SSH key..."

    # Test passwordless SSH access to host via observer ProxyJump.
    local key_ok=0
    if ssh ${SSH_OPTS} -J "${proxy_user}@${proxy_ip}" \
            "${SSH_USER_HOST}@${host_ip}" "exit" 2>/dev/null; then
        key_ok=1
    fi

    # Skip deployment if key is already trusted and --force was not given.
    if [[ "$key_ok" -eq 1 && -z "$force" ]]; then
        INFO "[${device}] SSH key already in place — skipping."
        return 0
    fi

    INFO "[${device}] Deploying SSH key via ProxyJump through '${OBSERVER_PRIMARY}'..."
    # Use ssh-copy-id with ProxyJump — copies ~/.ssh/id_*.pub to host authorized_keys.
    if ! ssh-copy-id -o "ProxyJump=${proxy_user}@${proxy_ip}" \
            "${SSH_USER_HOST}@${host_ip}"; then
        ERROR "[${device}] SSH key deployment failed."
        return 1
    fi
}

# ==============================================================================
# --- _init_dirs ---
# @desc_short  : Creates the /opt/homelab directory structure on the host.
# ==============================================================================
function _init_dirs {
    local device="$1"

    INFO "[${device}] Step 2/6 — Creating directory structure..."

    # Create all required homelab subdirectories in a single remote call.
    execute_on_device "$device" \
        "mkdir -p \
            /opt/homelab/bin/hosts \
            /opt/homelab/bin/clients \
            /opt/homelab/bin/update \
            /opt/homelab/systemd \
            /opt/homelab/state/flags \
            /opt/homelab/state/applied_patches"
}

# ==============================================================================
# --- _init_scripts ---
# @desc_short  : Pushes all scripts from the local mirror to the host via tar stream.
# @parameter   : $1 | device     | Host name
# @parameter   : $2 | host_ip    | Resolved host IP
# @parameter   : $3 | proxy_ip   | Observer IP for ProxyJump
# @parameter   : $4 | proxy_user | Observer SSH user for ProxyJump
# @notes       : Direct SSH/tar — lx cmd cannot handle binary streams.
#                --no-same-owner: remote files owned by root, not local uid 1000.
#                Mirror structure mirrors the remote filesystem root —
#                extracting to / restores the correct remote paths.
# ==============================================================================
function _init_scripts {
    local device="$1" host_ip="$2" proxy_ip="$3" proxy_user="$4"
    local mirror_path="${PATH_EXTENSION_DATA}/mirror/host/${device}"  # local mirror root for this host

    INFO "[${device}] Step 3/6 — Deploying scripts from mirror..."

    # Skip silently if no mirror has been populated yet.
    if [[ ! -d "$mirror_path" ]]; then
        WARN "[${device}] No mirror found at ${mirror_path} — scripts skipped."
        WARN "[${device}] Populate the mirror with 'files --fetch', then re-run --init."
        return 0
    fi

    # Stream tar archive from mirror root through ProxyJump to host filesystem root.
    if ! tar -czf - -C "$mirror_path" . \
            | ssh ${SSH_OPTS} -J "${proxy_user}@${proxy_ip}" \
                "${SSH_USER_HOST}@${host_ip}" \
                "sudo tar -xzf - -C / --no-same-owner"; then
        ERROR "[${device}] Script deployment failed."
        return 1
    fi

    # Mark all deployed shell scripts as executable — idempotent, safe to repeat.
    execute_on_device "$device" "find /opt/homelab -name '*.sh' -exec chmod +x {} +" || true
}

# ==============================================================================
# --- _init_node_name ---
# @desc_short  : Writes the logical device name to the state file on the host.
# @notes       : Scripts on the device read this file to identify themselves at runtime.
# ==============================================================================
function _init_node_name {
    local device="$1"

    INFO "[${device}] Step 4/6 — Writing node name..."

    # Write the logical name so on-device scripts can resolve their own identity.
    execute_on_device "$device" "echo '${device}' > /opt/homelab/state/node_name"
}

# ==============================================================================
# --- _init_conf ---
# @desc_short  : Deploys the local config.conf to the host as homelab.conf.
# @notes       : Uses sudo tee to write to the privileged /opt/homelab/ path.
#                Skips gracefully if the local config does not exist yet.
# ==============================================================================
function _init_conf {
    local device="$1"
    local conf_local="${PATH_EXTENSION_DATA}/config.conf"  # local homelab.conf (desktop copy)
    local ip user

    INFO "[${device}] Step 5/6 — Deploying homelab.conf..."

    # Skip if local config has not been fetched yet — do not push an empty file.
    if [[ ! -f "$conf_local" ]]; then
        WARN "[${device}] Local config.conf not found — homelab.conf skipped."
        WARN "[${device}] Run 'setup globals --fetch' first, then re-run --init."
        return 0
    fi

    # Resolve connection details for direct SSH pipe.
    ip=$(get_device_ip "$device")         || return 1
    user=$(get_device_ssh_user "$device") || return 1

    # Pipe local config into remote file via sudo tee (required for /opt/ write access).
    if ! ssh ${SSH_OPTS} "${user}@${ip}" \
            "sudo tee '/opt/homelab/homelab.conf' > /dev/null" < "$conf_local"; then
        ERROR "[${device}] homelab.conf deployment failed."
        return 1
    fi
}

# ==============================================================================
# --- _init_units ---
# @desc_short  : Runs generate-units.sh on the host to create systemd units from templates.
# @notes       : Requires the script to have been deployed in step 3 first.
# ==============================================================================
function _init_units {
    local device="$1"

    INFO "[${device}] Step 6/6 — Generating systemd units..."

    # Run the unit generator that was deployed in _init_scripts.
    execute_on_device "$device" "bash /opt/homelab/systemd/generate-units.sh"
}
