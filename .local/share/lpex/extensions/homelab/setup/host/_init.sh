#!/bin/bash
# ==============================================================================
# @meta_name        : setup/host/_init.sh
# @desc_short       : Host-Initialisierung (SSH-Key, Dirs, Scripts, Units).
#                     Sourced by setup/host/main.sh.
# ==============================================================================

# ==============================================================================
# --- _action_init ---
# @desc_short   : Initializes a host with all required directories, scripts,
#                 node_name, homelab.conf, and generates systemd units.
# @parameter    : $1 | id    | Host ID
# @parameter    : $2 | name  | Logical device name (e.g. host_1)
# @parameter    : $3 | force | "1" = skip idempotency checks
# ==============================================================================
function _action_init {
    local id="$1" name="$2" force="${3:-0}"
    local host_ip obs_id obs_ip mirror_path

    host_ip=$(_device_ip "host" "$id") || return 1
    obs_id=$(_leader_observer_id)
    obs_ip=$(_device_ip "observer" "$obs_id") || return 1
    mirror_path="${PATH_HOMELAB_DATA}/mirror/host/${name}"

    lx output --section "Init [${name}] (${host_ip})"

    # Step 1: SSH-Key --- deploy if not yet present (or --force)
    INFO "Schritt 1/6 — SSH-Key prüfen..."
    local key_check_cmd="ssh ${_SSH_OPTS[*]} root@${host_ip} exit 2>/dev/null && echo ok || echo fail"
    local key_status
    key_status=$(ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" "$key_check_cmd" 2>/dev/null)

    # Deploy SSH key if connection failed or --force is set
    if [[ "$key_status" != "ok" || "$force" == "1" ]]; then
        INFO "SSH-Key wird deployed — ProxyJump via observer ${obs_id}..."
        ssh-copy-id -o "ProxyJump=${SSH_USER_OBSERVER}@${obs_ip}" "${SSH_USER_HOST}@${host_ip}" || return 1
    else
        INFO "SSH-Key bereits gesetzt."
    fi

    # Step 2: Create directory structure on host
    INFO "Schritt 2/6 — Verzeichnisstruktur anlegen..."
    _run_on_host "$id" \
        "mkdir -p /opt/homelab/bin/hosts \
                  /opt/homelab/bin/clients \
                  /opt/homelab/bin/update \
                  /opt/homelab/bin/setup/patches \
                  /opt/homelab/systemd \
                  /opt/homelab/state/flags \
                  /opt/homelab/state/applied_patches" || return 1

    # Step 3: Push all scripts from local mirror via rsync through observer
    INFO "Schritt 3/6 — Scripts deployen (${mirror_path})..."
    if [[ ! -d "$mirror_path" ]]; then
        WARN "Kein Mirror-Verzeichnis gefunden: ${mirror_path} — Scripts übersprungen."
    else
        rsync -az --rsh="ssh ${_SSH_OPTS[*]} -J ${SSH_USER_OBSERVER}@${obs_ip}" \
            "${mirror_path}/opt/homelab/" \
            "${SSH_USER_HOST}@${host_ip}:/opt/homelab/" || return 1
        # Make all .sh files executable
        _run_on_host "$id" "find /opt/homelab -name '*.sh' -exec chmod +x {} +" || true
    fi

    # Step 4: Write the logical node name to state/node_name
    INFO "Schritt 4/6 — Node-Namen schreiben (${name})..."
    _run_on_host "$id" "echo '${name}' > /opt/homelab/state/node_name" || return 1

    # Step 5: Push homelab.conf initially (only observer_1 is the permanent source)
    INFO "Schritt 5/6 — homelab.conf initial deployen..."
    local conf_src="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"
    if [[ -f "$conf_src" ]]; then
        rsync -az --rsh="ssh ${_SSH_OPTS[*]} -J ${SSH_USER_OBSERVER}@${obs_ip}" \
            "$conf_src" "${SSH_USER_HOST}@${host_ip}:/opt/homelab/homelab.conf" || true
    else
        WARN "homelab.conf nicht gefunden: ${conf_src} — wird übersprungen."
    fi

    # Step 6: Generate systemd units from templates
    INFO "Schritt 6/6 — Systemd-Units generieren..."
    _run_on_host "$id" "bash /opt/homelab/systemd/generate-units.sh" || return 1

    OK "[${name}] initialisiert."
}
