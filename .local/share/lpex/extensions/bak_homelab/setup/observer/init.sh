#!/bin/bash
# ==============================================================================
# @meta_name        : setup/observer/init.sh
# @desc_short       : Observer-Initialisierung (9 Schritte).
#                     Sourced by setup/observer/main.sh.
# ==============================================================================

# ==============================================================================
# --- action_init ---
# @desc_short   : Initializes an observer: SSH-key, dirs, scripts, node_name,
#                 state flags, homelab.conf, NFS mounts, systemd units.
# @parameter    : $1 | id    | Observer ID
# @parameter    : $2 | name  | Logical device name (e.g. observer_1)
# @parameter    : $3 | force | "1" = skip idempotency checks
# ==============================================================================
function action_init {
    local id="$1" name="$2" force="${3:-0}"
    local obs_ip mirror_path

    obs_ip=$(device_ip "observer" "$id") || return 1
    mirror_path="${PATH_HOMELAB_DATA}/mirror/observer/${name}"

    lx output --section "Init [${name}] (${obs_ip})"

    # Step 1: SSH-Key — deploy if not yet present (or --force)
    INFO "Schritt 1/9 — SSH-Key prüfen..."
    local key_ok
    key_ok=$(ssh "${_SSH_OPTS[@]}" "${SSH_USER_OBSERVER}@${obs_ip}" "echo ok" 2>/dev/null || echo "fail")

    if [[ "$key_ok" != "ok" || "$force" == "1" ]]; then
        INFO "SSH-Key wird deployed..."
        ssh-copy-id "${SSH_USER_OBSERVER}@${obs_ip}" || return 1
    else
        INFO "SSH-Key bereits gesetzt."
    fi

    # Step 2: Create homelab root and subdirectory structure
    INFO "Schritt 2/9 — Verzeichnisstruktur anlegen..."
    run_on_observer "$id" \
        "sudo mkdir -p /opt/homelab && sudo chown -R fadmin:fadmin /opt/homelab && \
         mkdir -p /opt/homelab/bin/observer \
                  /opt/homelab/bin/hosts \
                  /opt/homelab/bin/clients \
                  /opt/homelab/bin/update \
                  /opt/homelab/bin/setup/patches \
                  /opt/homelab/systemd \
                  /opt/homelab/state/flags/unit_skip \
                  /opt/homelab/state/applied_patches" || return 1

    # Step 3: Push all scripts from local mirror via rsync
    INFO "Schritt 3/9 — Scripts deployen (${mirror_path})..."
    if [[ ! -d "$mirror_path" ]]; then
        WARN "Kein Mirror-Verzeichnis gefunden: ${mirror_path} — Scripts übersprungen."
    else
        rsync -az --rsh="ssh ${_SSH_OPTS[*]}" \
            "${mirror_path}/opt/homelab/" \
            "${SSH_USER_OBSERVER}@${obs_ip}:/opt/homelab/" || return 1
        run_on_observer "$id" "find /opt/homelab -name '*.sh' -exec chmod +x {} +" || true
    fi

    # Step 4: Write the logical node name
    INFO "Schritt 4/9 — Node-Namen schreiben (${name})..."
    run_on_observer "$id" "echo '${name}' > /opt/homelab/state/node_name" || return 1

    # Step 5: Initialize state flags (observer_leader + allow_zfs_sync per host)
    INFO "Schritt 5/9 — State-Flags initialisieren..."

    # observer_2 starts as standby — observer_leader points to observer_1
    if [[ "$name" == "observer_2" ]]; then
        run_on_observer "$id" "echo 'observer_1' > /opt/homelab/state/flags/observer_leader" || return 1
    else
        run_on_observer "$id" "echo '${name}' > /opt/homelab/state/flags/observer_leader" || return 1
    fi

    # Initialize allow_zfs_sync flag for each known host (default: enabled)
    local -a host_rows=()
    lx db --file "homelab_conf.db" --table "hosts" --select @host_rows \
        --cols "name" --sort "id ASC" 2>/dev/null
    for h_name in "${host_rows[@]}"; do
        [[ -z "$h_name" ]] && continue
        run_on_observer "$id" "echo '1' > /opt/homelab/state/flags/allow_zfs_sync_${h_name}" || true
    done

    # Step 6: Push homelab.conf — observer_1 is permanent source
    INFO "Schritt 6/9 — homelab.conf deployen..."
    local conf_src="${PATH_HOMELAB_DATA}/mirror/observer/observer_1/opt/homelab/homelab.conf"
    if [[ -f "$conf_src" ]]; then
        rsync -az --rsh="ssh ${_SSH_OPTS[*]}" \
            "$conf_src" "${SSH_USER_OBSERVER}@${obs_ip}:/opt/homelab/homelab.conf" || true
    else
        WARN "homelab.conf nicht gefunden: ${conf_src} — wird übersprungen."
    fi

    # Step 7: Start NFS mounts
    INFO "Schritt 7/9 — NFS-Mounts starten..."
    run_on_observer "$id" \
        "sudo systemctl start mnt-pool_fast-data.mount mnt-pool_big-data.mount 2>/dev/null || true"

    # Step 8: Generate and enable systemd units from templates
    INFO "Schritt 8/9 — Systemd-Units generieren..."
    run_on_observer "$id" "sudo bash /opt/homelab/systemd/generate-units.sh" || return 1

    # Step 9: Enable obs-boot-state-restore service
    INFO "Schritt 9/9 — obs-boot-state-restore enablen..."
    run_on_observer "$id" "sudo systemctl enable obs-boot-state-restore.service" || true

    OK "[${name}] initialisiert."
}
