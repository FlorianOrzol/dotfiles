#!/bin/bash
# ==============================================================================
# @meta_name        : config/add/main.sh
# @desc_short       : Add a new key-value entry to homelab_conf.db.
# ==============================================================================
source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/extension_global.sh"

function extension_start {
    _config_init_db   # ensure settings table exists before any read or write

    # Require both key and value to proceed
    if [[ -z "${ARG_KEY:-}" || -z "${ARG_VALUE:-}" ]]; then
        ERROR "--key and --value are required."
        return 1
    fi

    # Reject duplicate keys — use 'config edit' to change an existing one
    if _config_key_exists "$ARG_KEY"; then
        ERROR "Key '${ARG_KEY}' already exists. Use 'config edit' to change it."
        return 1
    fi

    _config_set_value "$ARG_KEY" "$ARG_VALUE"   # insert the new key-value pair
    OK "Entry set: ${ARG_KEY} = ${ARG_VALUE}"
}
