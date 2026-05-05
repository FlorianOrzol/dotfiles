#!/bin/bash
# ==============================================================================
# @meta_name        : config/list/main.sh
# @desc_short       : List all key-value entries from homelab_conf.db.
# ==============================================================================
source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/extension_global.sh"

function extension_start {
    _config_init_db   # ensure settings table exists before querying

    local filter="${ARG_FILTER//\'/\'\'}"                    # escape filter for SQL LIKE clause
    local db_path="${PATH_EXTENSION_DATA}/homelab_conf.db"  # absolute path for sqlite3

    local sql
    if [[ -n "$filter" ]]; then
        # Wrap in a WHERE clause when a filter string was provided
        sql="SELECT key||' = '||value FROM settings WHERE key LIKE '%${filter}%' ORDER BY key;"
    else
        # No filter — list all entries sorted by key
        sql="SELECT key||' = '||value FROM settings ORDER BY key;"
    fi

    # Execute the query; print a warning and exit cleanly on empty DB or error
    sqlite3 "$db_path" "$sql" 2>/dev/null || {
        WARN "DB is empty or not reachable."
        return 0
    }
}
