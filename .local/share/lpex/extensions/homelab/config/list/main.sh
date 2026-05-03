#!/bin/bash
# ==============================================================================
# @meta_name        : config/list/main.sh
# @desc_short       : Zeigt alle Konfigurationswerte aus homelab_conf.db als Key-Value-Liste.
# ==============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../_helpers.sh"

function extension_start {
    _config_init_db

    local filter="${ARG_FILTER//\'/\'\'}"
    local db_path="${PATH_EXTENSION_DATA}/homelab_conf.db"

    # Alle Werte als KEY = VALUE via sqlite3 UNION
    local sql
    sql="SELECT 'IP_HOST_'||id||' = '||ip AS entry FROM hosts
UNION ALL SELECT 'DEVICENAME_HOST_'||id||' = '||name FROM hosts
UNION ALL SELECT 'MAC_HOST_'||id||' = '||mac FROM hosts
UNION ALL SELECT 'IP_OBSERVER_'||id||' = '||ip FROM observers
UNION ALL SELECT 'DEVICENAME_OBSERVER_'||id||' = '||name FROM observers
UNION ALL SELECT 'ZFS_POOL_'||id||' = '||dataset FROM zfs_pools
UNION ALL SELECT key||' = '||value FROM settings
ORDER BY entry;"

    if [[ -n "$filter" ]]; then
        sql="SELECT entry FROM (
SELECT 'IP_HOST_'||id||' = '||ip AS entry FROM hosts
UNION ALL SELECT 'DEVICENAME_HOST_'||id||' = '||name FROM hosts
UNION ALL SELECT 'MAC_HOST_'||id||' = '||mac FROM hosts
UNION ALL SELECT 'IP_OBSERVER_'||id||' = '||ip FROM observers
UNION ALL SELECT 'DEVICENAME_OBSERVER_'||id||' = '||name FROM observers
UNION ALL SELECT 'ZFS_POOL_'||id||' = '||dataset FROM zfs_pools
UNION ALL SELECT key||' = '||value FROM settings
) WHERE entry LIKE '%${filter}%'
ORDER BY entry;"
    fi

    sqlite3 "$db_path" "$sql" 2>/dev/null || {
        WARN "DB noch leer oder nicht erreichbar."
        return 0
    }
}
