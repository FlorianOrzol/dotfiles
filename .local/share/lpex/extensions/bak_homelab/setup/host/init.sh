#!/bin/bash
# ==============================================================================
# @meta_name        : setup/host/init.sh
# @desc_short       : Host-Initialisierung (SSH-Key, Dirs, Scripts, Units).
#                     Sourced by setup/host/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_init ---
# @desc_short   : Initializes a host: SSH-key, directories, scripts, node_name,
#                 homelab.conf, and generates systemd units.
# @parameter    : $1 | id    | Host ID
# @parameter    : $2 | name  | Logical device name (e.g. host_1)
# @parameter    : $3 | force | "1" = skip idempotency checks
# ==============================================================================
function action_init {
    local id="$1" name="$2" force="${3:-0}"
    local host_ip obs_id obs_ip mirror_path

    # Resolve host IP — abort if not found in DB or config
    host_ip=$(device_ip "host" "$id") || return 1
    # Determine which observer to use as jump host
    obs_id=$(leader_observer_id)
    # Resolve the leader observer's IP — abort if not found
    obs_ip=$(device_ip "observer" "$obs_id") || return 1
    # Determine local mirror path for rsync
    mirror_path="${PATH_HOMELAB_DATA}/mirror/host/${name}"

    lx output --section "Init [${name}] (${host_ip})"

    # Step 1: SSH-Key — deploy if not yet present (or --force)
    INFO "Schritt 1/6 — SSH-Key prüfen..."
    # Test if the desktop's SSH key is already trusted on the host via the observer jump
    local key_check_cmd="ssh ${_SSH_OPTS[*]} root@${host_ip} exit 2>/dev/null && echo ok || echo fail"
    local key_status
    key_status=$(ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" "$key_check_cmd" 2>/dev/null)

    # Deploy SSH key if test failed or --force was set
    if [[ "$key_status" != "ok" || "$force" == "1" ]]; then
        INFO "SSH-Key wird deployed — ProxyJump via observer ${obs_id}..."
        ssh-copy-id -o "ProxyJump=${SSH_USER_OBSERVER}@${obs_ip}" "${SSH_USER_HOST}@${host_ip}" || return 1
    else
        INFO "SSH-Key bereits gesetzt."
    fi

    # Step 2: Create directory structure on host
    INFO "Schritt 2/6 — Verzeichnisstruktur anlegen..."
    # Create all required homelab directories on the host in one SSH call
    run_on_host "$id" \
        "mkdir -p /opt/homelab/bin/hosts \
                  /opt/homelab/bin/clients \
                  /opt/homelab/bin/update \
                  /opt/homelab/bin/setup/patches \
                  /opt/homelab/systemd \
                  /opt/homelab/state/flags \
                  /opt/homelab/state/applied_patches" || return 1

    # Step 3: Push all scripts from local mirror via rsync through observer
    INFO "Schritt 3/6 — Scripts deployen (${mirror_path})..."
    # Skip rsync if no local mirror directory has been populated yet
    if [[ ! -d "$mirror_path" ]]; then
        WARN "Kein Mirror-Verzeichnis gefunden: ${mirror_path} — Scripts übersprungen."
    else
        # Push mirror content to host via rsync, using observer as SSH jump host
        rsync -az --rsh="ssh ${_SSH_OPTS[*]} -J ${SSH_USER_OBSERVER}@${obs_ip}" \
            "${mirror_path}/opt/homelab/" \
            "${SSH_USER_HOST}@${host_ip}:/opt/homelab/" || return 1
        # Make all pushed shell scripts executable
        run_on_host "$id" "find /opt/homelab -name '*.sh' -exec chmod +x {} +" || true
    fi

    # Step 4: Write the logical node name to state/node_name
    INFO "Schritt 4/6 — Node-Namen schreiben (${name})..."
    # Store the logical name so scripts can identify this device at runtime
    run_on_host "$id" "echo '${name}' > /opt/homelab/state/node_name" || return 1

    # Step 5: Push homelab.conf initially — observer_1 is the permanent source
    INFO "Schritt 5/6 — homelab.conf initial deployen..."
    local conf_src="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"
    # Only push if the local mirror copy exists — skip silently otherwise
    if [[ -f "$conf_src" ]]; then
        rsync -az --rsh="ssh ${_SSH_OPTS[*]} -J ${SSH_USER_OBSERVER}@${obs_ip}" \
            "$conf_src" "${SSH_USER_HOST}@${host_ip}:/opt/homelab/homelab.conf" || true
    else
        WARN "homelab.conf nicht gefunden: ${conf_src} — wird übersprungen."
    fi

    # Step 6: Generate systemd units from templates
    INFO "Schritt 6/6 — Systemd-Units generieren..."
    # Run the unit generator script that was just deployed
    run_on_host "$id" "bash /opt/homelab/systemd/generate-units.sh" || return 1

    OK "[${name}] initialisiert."
}
