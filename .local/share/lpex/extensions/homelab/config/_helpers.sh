#!/bin/bash
# ==============================================================================
# @meta_name        : config/_helpers.sh
# @desc_short       : DB-Hilfsfunktionen für alle config-Submodule.
# ==============================================================================

function _config_init_db {
    lx db --file "homelab_conf.db" --table "hosts" --create-table \
        --cols "id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT '', ip TEXT NOT NULL DEFAULT '', mac TEXT NOT NULL DEFAULT ''"
    lx db --file "homelab_conf.db" --table "observers" --create-table \
        --cols "id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT '', ip TEXT NOT NULL DEFAULT ''"
    lx db --file "homelab_conf.db" --table "zfs_pools" --create-table \
        --cols "id INTEGER PRIMARY KEY AUTOINCREMENT, dataset TEXT NOT NULL UNIQUE"
    lx db --file "homelab_conf.db" --table "settings" --create-table \
        --cols "key TEXT PRIMARY KEY, value TEXT NOT NULL"
    lx db --file "homelab_conf.db" --exec \
        "CREATE TABLE IF NOT EXISTS conf_targets (id INTEGER PRIMARY KEY AUTOINCREMENT, host_id INTEGER NOT NULL, container_id INTEGER NOT NULL, UNIQUE(host_id, container_id));"
}

# Parse key → sets globals: _CKEY_TABLE, _CKEY_ID, _CKEY_COL, _CKEY_IS_STRUCT
function _config_parse_key {
    local key="$1"
    _CKEY_TABLE="" _CKEY_ID="" _CKEY_COL="" _CKEY_IS_STRUCT=0
    if   [[ "$key" =~ ^IP_HOST_([0-9]+)$            ]]; then _CKEY_TABLE="hosts";     _CKEY_ID="${BASH_REMATCH[1]}"; _CKEY_COL="ip";      _CKEY_IS_STRUCT=1
    elif [[ "$key" =~ ^DEVICENAME_HOST_([0-9]+)$     ]]; then _CKEY_TABLE="hosts";     _CKEY_ID="${BASH_REMATCH[1]}"; _CKEY_COL="name";    _CKEY_IS_STRUCT=1
    elif [[ "$key" =~ ^MAC_HOST_([0-9]+)$            ]]; then _CKEY_TABLE="hosts";     _CKEY_ID="${BASH_REMATCH[1]}"; _CKEY_COL="mac";     _CKEY_IS_STRUCT=1
    elif [[ "$key" =~ ^IP_OBSERVER_([0-9]+)$         ]]; then _CKEY_TABLE="observers"; _CKEY_ID="${BASH_REMATCH[1]}"; _CKEY_COL="ip";      _CKEY_IS_STRUCT=1
    elif [[ "$key" =~ ^DEVICENAME_OBSERVER_([0-9]+)$ ]]; then _CKEY_TABLE="observers"; _CKEY_ID="${BASH_REMATCH[1]}"; _CKEY_COL="name";    _CKEY_IS_STRUCT=1
    elif [[ "$key" =~ ^ZFS_POOL_([0-9]+)$           ]]; then _CKEY_TABLE="zfs_pools"; _CKEY_ID="${BASH_REMATCH[1]}"; _CKEY_COL="dataset"; _CKEY_IS_STRUCT=1
    else _CKEY_TABLE="settings"; _CKEY_ID=""; _CKEY_COL="value"; _CKEY_IS_STRUCT=0
    fi
}

# Returns 0 if key exists, 1 if not
function _config_key_exists {
    local key="$1"
    _config_parse_key "$key"
    local -a r=()
    case "$_CKEY_TABLE" in
        hosts|observers)
            lx db --file "homelab_conf.db" --table "$_CKEY_TABLE" --select @r \
                --cols "id" --where "id=${_CKEY_ID}" --limit 1 2>/dev/null ;;
        zfs_pools)
            lx db --file "homelab_conf.db" --table "zfs_pools" --select @r \
                --cols "id" --where "id=${_CKEY_ID}" --limit 1 2>/dev/null ;;
        settings)
            lx db --file "homelab_conf.db" --table "settings" --select @r \
                --cols "key" --where "key='${key}'" --limit 1 2>/dev/null ;;
    esac
    [[ -n "${r[0]:-}" ]]
}

# Upsert a key-value pair (uses --exec for all writes to avoid lx db --update bug)
function _config_set_value {
    local key="$1" value="$2"
    _config_parse_key "$key"
    local esc_val="${value//\'/\'\'}"
    local esc_key="${key//\'/\'\'}"
    case "$_CKEY_TABLE" in
        hosts)
            if _config_key_exists "$key"; then
                lx db --file "homelab_conf.db" --exec \
                    "UPDATE hosts SET ${_CKEY_COL}='${esc_val}' WHERE id=${_CKEY_ID};"
            else
                case "$_CKEY_COL" in
                    ip)   lx db --file "homelab_conf.db" --exec \
                              "INSERT OR IGNORE INTO hosts(id,name,ip,mac) VALUES(${_CKEY_ID},'host_${_CKEY_ID}','${esc_val}','');" ;;
                    name) lx db --file "homelab_conf.db" --exec \
                              "INSERT OR IGNORE INTO hosts(id,name,ip,mac) VALUES(${_CKEY_ID},'${esc_val}','','');" ;;
                    mac)  lx db --file "homelab_conf.db" --exec \
                              "INSERT OR IGNORE INTO hosts(id,name,ip,mac) VALUES(${_CKEY_ID},'host_${_CKEY_ID}','','${esc_val}');" ;;
                esac
            fi ;;
        observers)
            if _config_key_exists "$key"; then
                lx db --file "homelab_conf.db" --exec \
                    "UPDATE observers SET ${_CKEY_COL}='${esc_val}' WHERE id=${_CKEY_ID};"
            else
                case "$_CKEY_COL" in
                    ip)   lx db --file "homelab_conf.db" --exec \
                              "INSERT OR IGNORE INTO observers(id,name,ip) VALUES(${_CKEY_ID},'observer_${_CKEY_ID}','${esc_val}');" ;;
                    name) lx db --file "homelab_conf.db" --exec \
                              "INSERT OR IGNORE INTO observers(id,name,ip) VALUES(${_CKEY_ID},'${esc_val}','');" ;;
                esac
            fi ;;
        zfs_pools)
            if _config_key_exists "$key"; then
                lx db --file "homelab_conf.db" --exec \
                    "UPDATE zfs_pools SET dataset='${esc_val}' WHERE id=${_CKEY_ID};"
            else
                lx db --file "homelab_conf.db" --exec \
                    "INSERT OR IGNORE INTO zfs_pools(id,dataset) VALUES(${_CKEY_ID},'${esc_val}');"
            fi ;;
        settings)
            lx db --file "homelab_conf.db" --exec \
                "INSERT OR REPLACE INTO settings(key,value) VALUES('${esc_key}','${esc_val}');" ;;
    esac
}

# Returns the current value of a key from DB (empty string if not found)
function _config_get_current_value {
    local key="$1"
    [[ -z "$key" ]] && return
    _config_parse_key "$key"
    local -a _r=()
    case "$_CKEY_TABLE" in
        hosts|observers|zfs_pools)
            lx db --file "homelab_conf.db" --table "$_CKEY_TABLE" --select @_r \
                --cols "$_CKEY_COL" --where "id=${_CKEY_ID}" --limit 1 2>/dev/null ;;
        settings)
            lx db --file "homelab_conf.db" --table "settings" --select @_r \
                --cols "value" --where "key='${key//\'/\'\'}'" --limit 1 2>/dev/null ;;
    esac
    echo "${_r[0]:-}"
}

# Delete a key from DB (structured keys: deletes entire row; settings: deletes row)
function _config_delete_key {
    local key="$1"
    _config_parse_key "$key"
    case "$_CKEY_TABLE" in
        hosts)     lx db --file "homelab_conf.db" --exec "DELETE FROM hosts WHERE id=${_CKEY_ID};" ;;
        observers) lx db --file "homelab_conf.db" --exec "DELETE FROM observers WHERE id=${_CKEY_ID};" ;;
        zfs_pools) lx db --file "homelab_conf.db" --exec "DELETE FROM zfs_pools WHERE id=${_CKEY_ID};" ;;
        settings)  lx db --file "homelab_conf.db" --exec "DELETE FROM settings WHERE key='${key//\'/\'\'}';" ;;
    esac
}
