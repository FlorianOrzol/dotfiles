#!/bin/bash
# ==============================================================================
# @meta_name        : _delete.sh
# @desc_short       : Container deletion — stop, destroy, clean up all traces.
#                     Sourced by setup/container/main.sh.
# ==============================================================================

# --- action_delete ---
# @desc_short  : Deletes a container after two confirmations and cleans up its traces.
# @desc_detailed: Order: overview → (if HA-managed) pause HA → (if running) confirm
#                 shutdown → confirm destroy by typing the ID → pct destroy → cleanup
#                 (HA list, host conf_targets, share state, local mirror, event log)
#                 → refresh the host's status. Declining a confirmation reverts the
#                 HA pause and changes nothing else.
# @usage       : action_delete <container_id>
# @parameter   : $1 | container_id | Proxmox VMID (e.g. 3060).
# ==============================================================================
function action_delete {
    local container_id="$1"
    local host status name ip user config ha_member=0 confirm_id=""

    # IDs are Proxmox VMIDs — reject anything non-numeric before it reaches pct
    [[ "$container_id" =~ ^[0-9]+$ ]] || { ERROR "Invalid container ID: '${container_id}'"; return 1; }

    # ShareData provides the NFS share this very command reads its state from — deleting
    # it would take down the share mid-operation and strand every other device's status
    if [[ "$container_id" == "$ID_CLIENT_SHAREDATA" ]]; then
        ERROR "CT ${container_id} is ShareData — deleting it would take the NFS share down with it. Refused."
        return 1
    fi

    host=$(find_container_host "$container_id") || return 1

    # Live name/status from the leader's lxc-live.txt — same source every status view uses
    status="unknown"; name="-"
    if [[ -f "$FILE_CONTAINER_LIVE" ]]; then
        read -r name status < <(awk -v id="$container_id" '$1==id {print $3, $5}' "$FILE_CONTAINER_LIVE")
        name="${name:--}"; status="${status:-unknown}"
    fi

    # Disks and bind mounts come straight from Proxmox — the mirror/docs could be stale
    ip=$(get_device_ip "$host")         || return 1
    user=$(get_device_ssh_user "$host") || return 1
    config=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
                "${user}@${ip}" "pct config ${container_id}" 2>/dev/null) || {
        ERROR "Could not read the Proxmox config of CT ${container_id} on ${host}."
        return 1
    }

    local -a ha_list
    _ha_read_list @ha_list
    local id_check
    for id_check in "${ha_list[@]}"; do
        [[ "$id_check" == "$container_id" ]] && ha_member=1
    done

    _delete_show_overview "$container_id" "$host" "$name" "$status" "$ha_member" "$config"

    # An HA-managed container races the watcher (it reconciles every 60s) for the
    # entire duration of the confirmations below — pause it now, before asking anything,
    # and lift the pause again on every early exit from this point on.
    (( ha_member )) && _ha_set_maintenance "$container_id"

    if [[ "$status" == "running" ]]; then
        if ! question "Shut down CT ${container_id} (${name}) before deleting it?"; then
            WARN "Deletion cancelled — CT ${container_id} keeps running."
            (( ha_member )) && _ha_clear_maintenance "$container_id"
            return 1
        fi

        INFO "Shutting down CT ${container_id}..."
        # 'pct shutdown' blocks up to its 60s default timeout and force-stops after —
        # it only returns once the container is actually stopped.
        if ! execute_on_device "$host" "pct shutdown ${container_id}"; then
            ERROR "Shutdown failed — aborting, nothing deleted."
            (( ha_member )) && _ha_clear_maintenance "$container_id"
            return 1
        fi
        OK "CT ${container_id} stopped."
    fi

    # Typed-ID confirmation instead of y/N — matches the Proxmox GUI convention for
    # a step that cannot be undone (unlike the shutdown above)
    lx input @confirm_id --prompt "Type ${container_id} to permanently delete CT ${container_id} (${name})"
    if [[ "$confirm_id" != "$container_id" ]]; then
        WARN "ID mismatch — deletion cancelled. Nothing was deleted."
        (( ha_member )) && _ha_clear_maintenance "$container_id"
        return 1
    fi

    INFO "Destroying CT ${container_id} on ${host}..."
    if ! execute_on_device "$host" "pct destroy ${container_id} --purge --destroy-unreferenced-disks"; then
        ERROR "pct destroy failed — CT ${container_id} may still exist. Nothing else was cleaned up."
        return 1
    fi
    OK "CT ${container_id} destroyed on ${host}."

    _delete_cleanup "$container_id" "$host" "$ha_member"

    # Host collector also refreshes every other client on it — cheap and correct either way
    refresh_device_status "host" "$host"

    _delete_final_report "$container_id" "$config"
}

# --- _delete_show_overview ---
# @desc_short  : Prints name, host, status, HA membership, disks and bind mounts.
# @usage       : _delete_show_overview <id> <host> <name> <status> <ha_member> <config>
# @parameter   : $1 | container_id | Proxmox VMID.
# @parameter   : $2 | host         | Host currently running the container.
# @parameter   : $3 | name         | Container hostname (or '-' if unknown).
# @parameter   : $4 | status       | 'running' | 'stopped' | 'unknown'.
# @parameter   : $5 | ha_member    | 1 if the container is HA-managed, else 0.
# @parameter   : $6 | config       | Full 'pct config' output.
# ==============================================================================
function _delete_show_overview {
    local container_id="$1" host="$2" name="$3" status="$4" ha_member="$5" config="$6"
    local color_status="$FONT_RED" disks_and_mounts ha_text="no"

    [[ "$status" == "running" ]] && color_status="$FONT_GREEN"    # same color convention as 'state ha'
    (( ha_member )) && ha_text="yes — will be removed from the boot order"

    lx output --section "CT ${container_id} — about to be deleted"
    printf '  %-10s %s\n'     "Name:"   "$name"
    printf '  %-10s %s\n'     "Host:"   "$host"
    printf '  %b%-10s %s%b\n' "$color_status" "Status:" "$status" "$FONT_RESET"
    printf '  %-10s %s\n'     "HA:"     "$ha_text"

    # rootfs and mpN lines are the only ones that name actual storage — everything
    # else in 'pct config' is CPU/network/feature settings, irrelevant here
    printf '\n  Disks / bind mounts:\n'
    disks_and_mounts=$(grep -E '^(rootfs|mp[0-9]+):' <<< "$config")
    if [[ -n "$disks_and_mounts" ]]; then
        while IFS= read -r line; do
            printf '    %s\n' "$line"
        done <<< "$disks_and_mounts"
    else
        printf '    (none found)\n'
    fi
    printf '\n'
}

# --- _delete_cleanup ---
# @desc_short  : Removes every LPEX-managed trace of a container after 'pct destroy'.
# @desc_detailed: Runs best-effort, step by step — one failed step must not skip the
#                 rest. Deliberately NOT touched: bind-mounted application data,
#                 existing vzdump archives, and the ZFS copy on the standby host
#                 (see _delete_final_report).
# @usage       : _delete_cleanup <container_id> <host> <ha_member>
# @parameter   : $1 | container_id | Proxmox VMID (already destroyed).
# @parameter   : $2 | host         | Host the container used to run on.
# @parameter   : $3 | ha_member    | 1 if the container was HA-managed, else 0.
# ==============================================================================
function _delete_cleanup {
    local container_id="$1"
    local host="$2"
    local ha_member="$3"
    local mirror_dir="${PATH_EXTENSION_DATA}/mirror/client/ct/${container_id}"

    # 1. HA boot order + per-CT watcher state — only for containers that were HA-managed
    if (( ha_member )); then
        _ha_remove_from_list "$container_id" "CT ${container_id} deleted by $(_ha_actor)"
        case $? in
            0) OK "Removed CT ${container_id} from the HA boot order." ;;
            2) : ;;    # no longer HA-managed (e.g. a concurrent 'setup ha --remove') — nothing to undo
            *) WARN "Could not update the HA boot order — check it manually (lpex homelab state ha)." ;;
        esac
    fi

    # 2. conf_targets on the host — best effort, the file may not exist or not list this ID
    execute_on_device "$host" "sed -i '/^${container_id}\$/d' /opt/homelab/state/conf_targets 2>/dev/null" || true

    # 3. Share-side client state in one go — status.json, ha_override.json, any ha_removed.json.
    #    No new ha_removed.json here: the container itself is gone, a marker on a
    #    directory this line deletes right after would be pointless.
    if [[ -n "$PATH_SHARE_STATE" ]] && share_mounted; then
        rm -rf "${PATH_SHARE_STATE}/clients/${container_id}"
        OK "Removed state/clients/${container_id}/ from the share."
    else
        WARN "NFS share not mounted — state/clients/${container_id}/ was not cleaned up. Remove it by hand once the share is back."
    fi

    # 4. Local mirror — git (the private dotfiles repo) is the safety net, no extra confirmation
    if [[ -d "$mirror_dir" ]]; then
        rm -rf "$mirror_dir"
        OK "Removed the local mirror at ${mirror_dir}."
    fi

    # 5. Observer event — fire and forget, matches every other state change in this extension
    observer_log_event "LPEX: CT ${container_id} deleted by $(_ha_actor)" "OK"
}

# --- _delete_final_report ---
# @desc_short  : Prints what was removed and what was deliberately left in place.
# @usage       : _delete_final_report <container_id> <config>
# @parameter   : $1 | container_id | Proxmox VMID (already destroyed).
# @parameter   : $2 | config       | Full 'pct config' output captured before destroy.
# ==============================================================================
function _delete_final_report {
    local container_id="$1"
    local config="$2"
    local rootfs_spec storage_id volume_name dataset_guess

    lx output --section "CT ${container_id} deleted"
    OK "Container, HA entry, share state and local mirror are gone."

    # rootfs is "<storage>:<volume>,size=<n>" — on this homelab the storage id matches
    # the ZFS pool's leaf name (verified for CT 3060: storage 'Container' ==
    # dataset 'zfs-pve/Container/...'), so the standby's stale path can be named exactly
    rootfs_spec=$(grep '^rootfs:' <<< "$config")
    if [[ -n "$rootfs_spec" ]]; then
        rootfs_spec="${rootfs_spec#rootfs: }"
        storage_id="${rootfs_spec%%:*}"
        volume_name="${rootfs_spec#*:}"; volume_name="${volume_name%%,*}"
        dataset_guess="zfs-pve/${storage_id}/${volume_name}"
        WARN "The standby host keeps a stale copy at ${dataset_guess} until the next nightly backup flags it as an orphan (sync-zfs-data.sh) — automatic cleanup there is not built yet."
    fi

    INFO "Bind-mounted application data and existing vzdump archives were left untouched — remove them by hand if they are no longer needed."
}
