#!/bin/bash
# ==============================================================================
# @meta_name        : config/manage.sh
# @desc_short       : homelab_conf.db Einträge verwalten (hosts, observers, settings).
#                     Sourced by config/main.sh.
# ==============================================================================

# ==============================================================================
# --- db_init_tables ---
# @desc_short   : Creates all required tables in homelab_conf.db if not present.
# ==============================================================================
function db_init_tables {
    lx db --file "homelab_conf.db" --table "hosts" --create-table \
        --cols "id INTEGER PRIMARY KEY, name TEXT NOT NULL, ip TEXT NOT NULL, mac TEXT NOT NULL DEFAULT ''"

    lx db --file "homelab_conf.db" --table "observers" --create-table \
        --cols "id INTEGER PRIMARY KEY, name TEXT NOT NULL, ip TEXT NOT NULL"

    lx db --file "homelab_conf.db" --table "zfs_pools" --create-table \
        --cols "id INTEGER PRIMARY KEY AUTOINCREMENT, dataset TEXT NOT NULL UNIQUE"

    lx db --file "homelab_conf.db" --table "settings" --create-table \
        --cols "key TEXT PRIMARY KEY, value TEXT NOT NULL"
}

# ==============================================================================
# --- action_list ---
# @desc_short   : Displays all entries from homelab_conf.db.
# ==============================================================================
function action_list {
    db_init_tables

    lx output --section "Hosts"
    lx db --file "homelab_conf.db" --table "hosts" --select

    lx output --section "Observers"
    lx db --file "homelab_conf.db" --table "observers" --select

    lx output --section "ZFS Pools"
    lx db --file "homelab_conf.db" --table "zfs_pools" --select

    lx output --section "Settings"
    lx db --file "homelab_conf.db" --table "settings" --select
}

# ==============================================================================
# --- action_set_host ---
# @desc_short   : Adds or updates a host entry in homelab_conf.db.
# ==============================================================================
function action_set_host {
    local id="$ARG_HOST"
    db_init_tables

    # Remove host entry if --remove is set
    if [[ -n "$ARG_REMOVE" ]]; then
        lx db --file "homelab_conf.db" --table "hosts" --delete --where "id='${id}'"
        OK "Host ${id} aus DB entfernt."
        return 0
    fi

    # Require at least one field to set
    if [[ -z "$ARG_NAME" && -z "$ARG_IP" && -z "$ARG_MAC" ]]; then
        ERROR "Mindestens --name, --ip oder --mac angeben."
        return 1
    fi

    # Check if host already exists
    local -a existing=()
    lx db --file "homelab_conf.db" --table "hosts" --select @existing \
        --cols "id" --where "id='${id}'" --limit 1 2>/dev/null

    if [[ -n "${existing[0]:-}" ]]; then
        # Update only provided fields
        local update_data=()
        [[ -n "$ARG_NAME" ]] && update_data+=("name" "$ARG_NAME")
        [[ -n "$ARG_IP" ]]   && update_data+=("ip"   "$ARG_IP")
        [[ -n "$ARG_MAC" ]]  && update_data+=("mac"  "$ARG_MAC")
        lx db --file "homelab_conf.db" --table "hosts" --update \
            --data "${update_data[@]}" --where "id='${id}'"
        OK "Host ${id} aktualisiert."
    else
        # Insert new host — name and ip required
        if [[ -z "$ARG_NAME" || -z "$ARG_IP" ]]; then
            ERROR "Neuer Host braucht mindestens --name und --ip."
            return 1
        fi
        lx db --file "homelab_conf.db" --table "hosts" --insert \
            --data "id" "$id" "name" "${ARG_NAME}" "ip" "${ARG_IP}" "mac" "${ARG_MAC:-}"
        OK "Host ${id} (${ARG_NAME}) hinzugefügt."
    fi
}

# ==============================================================================
# --- action_set_observer ---
# @desc_short   : Adds or updates an observer entry in homelab_conf.db.
# ==============================================================================
function action_set_observer {
    local id="$ARG_OBSERVER"
    db_init_tables

    if [[ -n "$ARG_REMOVE" ]]; then
        lx db --file "homelab_conf.db" --table "observers" --delete --where "id='${id}'"
        OK "Observer ${id} aus DB entfernt."
        return 0
    fi

    if [[ -z "$ARG_NAME" && -z "$ARG_IP" ]]; then
        ERROR "Mindestens --name oder --ip angeben."
        return 1
    fi

    local -a existing=()
    lx db --file "homelab_conf.db" --table "observers" --select @existing \
        --cols "id" --where "id='${id}'" --limit 1 2>/dev/null

    if [[ -n "${existing[0]:-}" ]]; then
        local update_data=()
        [[ -n "$ARG_NAME" ]] && update_data+=("name" "$ARG_NAME")
        [[ -n "$ARG_IP" ]]   && update_data+=("ip"   "$ARG_IP")
        lx db --file "homelab_conf.db" --table "observers" --update \
            --data "${update_data[@]}" --where "id='${id}'"
        OK "Observer ${id} aktualisiert."
    else
        if [[ -z "$ARG_NAME" || -z "$ARG_IP" ]]; then
            ERROR "Neuer Observer braucht mindestens --name und --ip."
            return 1
        fi
        lx db --file "homelab_conf.db" --table "observers" --insert \
            --data "id" "$id" "name" "${ARG_NAME}" "ip" "${ARG_IP}"
        OK "Observer ${id} (${ARG_NAME}) hinzugefügt."
    fi
}

# ==============================================================================
# --- action_set_sharedata ---
# @desc_short   : Sets ShareData container config in the settings table.
# ==============================================================================
function action_set_sharedata {
    db_init_tables

    if [[ -z "$ARG_SHARE_ID" && -z "$ARG_SHARE_IP" ]]; then
        ERROR "Mindestens --share-id oder --share-ip angeben."
        return 1
    fi

    # Upsert each provided field into settings table
    if [[ -n "$ARG_SHARE_ID" ]]; then
        lx db --file "homelab_conf.db" --exec \
            "INSERT OR REPLACE INTO settings (key, value) VALUES ('ID_CLIENT_SHAREDATA', '${ARG_SHARE_ID}');"
    fi
    if [[ -n "$ARG_SHARE_IP" ]]; then
        lx db --file "homelab_conf.db" --exec \
            "INSERT OR REPLACE INTO settings (key, value) VALUES ('IP_SHAREDATA', '${ARG_SHARE_IP}');"
    fi

    OK "ShareData-Konfiguration aktualisiert."
}

# ==============================================================================
# --- action_set_pool ---
# @desc_short   : Adds or removes a ZFS pool dataset entry.
# ==============================================================================
function action_set_pool {
    local dataset="$ARG_POOL"
    db_init_tables

    if [[ -n "$ARG_REMOVE" ]]; then
        lx db --file "homelab_conf.db" --table "zfs_pools" --delete \
            --where "dataset='${dataset}'"
        OK "ZFS Pool '${dataset}' entfernt."
        return 0
    fi

    lx db --file "homelab_conf.db" --exec \
        "INSERT OR IGNORE INTO zfs_pools (dataset) VALUES ('${dataset}');"
    OK "ZFS Pool '${dataset}' hinzugefügt."
}
