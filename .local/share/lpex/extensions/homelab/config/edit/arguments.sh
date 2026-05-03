#!/bin/bash
# @meta_name : config/edit/arguments.sh
source "$(dirname "${BASH_SOURCE[0]}")/../_helpers.sh"

function arguments {
    local _db="${PATH_EXTENSION_DATA}/homelab_conf.db"
    local _q="SELECT 'IP_HOST_'||id||' # '||ip              FROM hosts"
        _q+=" UNION ALL SELECT 'DEVICENAME_HOST_'||id||' # '||name  FROM hosts"
        _q+=" UNION ALL SELECT 'MAC_HOST_'||id||' # '||mac          FROM hosts"
        _q+=" UNION ALL SELECT 'IP_OBSERVER_'||id||' # '||ip        FROM observers"
        _q+=" UNION ALL SELECT 'DEVICENAME_OBSERVER_'||id||' # '||name FROM observers"
        _q+=" UNION ALL SELECT 'ZFS_POOL_'||id||' # '||dataset      FROM zfs_pools"
        _q+=" UNION ALL SELECT key||' # '||value                    FROM settings"
        _q+=" ORDER BY 1"

    arg_direct @key --description "Config key to edit" --fzf \
        --option-cmd "sqlite3 '${_db}' \"${_q}\" 2>/dev/null"

    arg_value @new_value \
        --description "New value (old: $(_config_get_current_value "${ARG_KEY:-}"))" \
        --depends-on "ARG_KEY"
}
